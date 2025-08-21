import 'package:flutter/foundation.dart';
import '../services/openai_service.dart';

class GameMessage {
  final String role; // 'user' or 'assistant' or 'system'
  final String content;
  final List<String> choices; // optional choices

  GameMessage({required this.role, required this.content, this.choices = const []});
}

class GameProvider extends ChangeNotifier {
  final List<GameMessage> _messages = [];
  bool _isLoading = false;
  String? _currentStoryImageUrl;

  List<GameMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get currentStoryImageUrl => _currentStoryImageUrl;

  final OpenAIService _openAIService = OpenAIService();

  Future<void> initWithSystemPrompt(String systemPrompt, {String? locale}) async {
    _messages.clear();
    _messages.add(GameMessage(role: 'system', content: systemPrompt));
    notifyListeners();

    // 초기 흐름 유도: 세계관과 캐릭터 입력 요청을 AI가 먼저 제시하도록 트리거
    await sendUserInput('게임을 시작한다. 타이틀 화면 이후 바로 세계관과 캐릭터 입력을 요청해줘.');
  }

  Future<void> sendUserInput(String input) async {
    _isLoading = true;
    _messages.add(GameMessage(role: 'user', content: input));
    notifyListeners();

    try {
      final aiResult = await _openAIService.completeStory(_messages);
      final text = aiResult.text;
      final choices = aiResult.choices;
      final imageUrl = aiResult.imageUrl;

      _messages.add(GameMessage(role: 'assistant', content: text, choices: choices));
      _currentStoryImageUrl = imageUrl;
    } catch (e) {
      _messages.add(GameMessage(role: 'assistant', content: '오류가 발생했어요. 잠시 후 다시 시도해 주세요. ($e)'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}


