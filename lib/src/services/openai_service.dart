import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../providers/game_provider.dart';

class StoryAIResult {
  final String text;
  final List<String> choices;
  final String? imageUrl;

  StoryAIResult({required this.text, this.choices = const [], this.imageUrl});
}

class OpenAIService {
  final String _apiBase = 'https://api.openai.com/v1/chat/completions';

  bool get _hasApiKey => (dotenv.env['OPENAI_API_KEY']?.isNotEmpty ?? false);
  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  String get _model => dotenv.env['OPENAI_MODEL']?.trim().isNotEmpty == true
      ? dotenv.env['OPENAI_MODEL']!.trim()
      : 'gpt-4.1';

  Future<StoryAIResult> completeStory(List<GameMessage> history) async {
    // 데모 모드: API 키가 없으면 빠른 로컬 응답을 생성해 테스트 가능하도록 처리
    if (!_hasApiKey) {
      final String lastUser = history.lastWhere((m) => m.role == 'user', orElse: () => GameMessage(role: 'user', content: '모험을 시작한다.')).content;
      final String demoText = '데모 모드 응답입니다. 다음 입력을 바탕으로 이야기를 전개합니다:\n\n"${lastUser}"\n\n- 북쪽의 작은 마을에서 여정이 시작됩니다.\n- 여관 앞 광장에서 수상한 인물이 당신을 지켜봅니다.';
      final List<String> demoChoices = ['광장으로 간다', '여관에 들어간다', '수상한 인물에게 다가간다'];
      return StoryAIResult(text: demoText, choices: demoChoices);
    }
    // GPT-4.1 모델 사용. 시스템 프롬프트 + 유저/어시스턴트 메세지 전달
    final messages = history
        .map((m) => {
              'role': m.role,
              'content': m.content,
            })
        .toList();

    // 추가: 응답 포맷을 규정하여 선택지와 이미지 키를 구조적으로 받음
    messages.add({
      'role': 'system',
      'content': '응답은 JSON으로만 반환하세요. 키: text(string), choices(string[]), image_prompt(string, optional).'
    });

    final body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.9,
    });

    final res = await http.post(
      Uri.parse(_apiBase),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      final content = data['choices'][0]['message']['content'] as String;

      // JSON 파싱 시도 (코드펜스/노이즈 제거 + 부분 JSON 추출)
      String text = '';
      List<String> choices = [];
      String? imageUrl;

      final Map<String, dynamic>? parsed = _tryParseStoryJson(content);
      if (parsed != null) {
        text = parsed['text']?.toString() ?? '';
        final dynamic c = parsed['choices'];
        if (c is List) {
          choices = c.map((e) => e.toString()).toList();
        }
        final imagePrompt = parsed['image_prompt']?.toString();
        if (imagePrompt != null && imagePrompt.isNotEmpty) {
          imageUrl = 'https://placehold.co/600x400/png?text=${Uri.encodeComponent(imagePrompt)}';
        }
      } else {
        // JSON 파싱 실패 시에도 화면에는 메시지만 보이도록 정리
        final regex = RegExp('"text"\s*:\s*"([\n\r\t\\"\u0000-\uFFFF]*?)"');
        final m = regex.firstMatch(content);
        if (m != null) {
          text = _unescapeJsonString(m.group(1)!);
        } else {
          text = _stripCodeFences(content).trim();
        }
      }

      return StoryAIResult(text: text, choices: choices, imageUrl: imageUrl);
    }

    throw Exception('OpenAI 오류: ${res.statusCode} ${res.body}');
  }
}

/// content 문자열에서 코드펜스 제거
String _stripCodeFences(String input) {
  final fence = RegExp(r'^```[a-zA-Z0-9_-]*\s*([\s\S]*?)\s*```\s*$', multiLine: true);
  final m = fence.firstMatch(input.trim());
  if (m != null) {
    return m.group(1) ?? input;
  }
  return input;
}

/// content에서 JSON 오브젝트를 견고하게 추출/파싱 시도
Map<String, dynamic>? _tryParseStoryJson(String content) {
  String cleaned = _stripCodeFences(content).trim();

  // 이미 순수 JSON처럼 보이면 바로 시도
  if (cleaned.startsWith('{') && cleaned.endsWith('}')) {
    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
  }

  // 본문에서 첫 '{'부터 밸런스 맞는 '}'까지 부분 추출
  final int start = cleaned.indexOf('{');
  if (start != -1) {
    int depth = 0;
    for (int i = start; i < cleaned.length; i++) {
      final ch = cleaned[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          final candidate = cleaned.substring(start, i + 1);
          try {
            final parsed = jsonDecode(candidate);
            if (parsed is Map<String, dynamic>) return parsed;
          } catch (_) {
            // 계속 시도
          }
        }
      }
    }
  }
  return null;
}

/// JSON 문자열의 이스케이프 해제 (최소한)
String _unescapeJsonString(String s) {
  return s
      .replaceAll('\\n', '\n')
      .replaceAll('\\r', '\r')
      .replaceAll('\\t', '\t')
      .replaceAll('\\"', '"')
      .replaceAll('\\\\', '\\');
}


