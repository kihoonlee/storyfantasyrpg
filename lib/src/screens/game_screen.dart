import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../constants/system_prompt.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController _inputController = TextEditingController();
  final String _systemPrompt = kSystemPrompt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().initWithSystemPrompt(_systemPrompt);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final topHeight = MediaQuery.of(context).size.height * 0.25; // 상단 이미지 1/4
    final latestAssistant = game.messages.where((m) => m.role == 'assistant').toList().isNotEmpty
        ? game.messages.where((m) => m.role == 'assistant').toList().last
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: topHeight,
              width: double.infinity,
              child: game.currentStoryImageUrl == null
                  ? Container(color: Colors.black12)
                  : Image.network(game.currentStoryImageUrl!, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Builder(
                  builder: (_) {
                    // 다음 턴이 시작되면(=로딩 중) 이전 응답을 숨기고 로딩만 표시
                    if (game.isLoading) {
                      return const Center(
                        child: SizedBox(
                          height: 32,
                          width: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      );
                    }

                    if (latestAssistant == null) {
                      return const SizedBox.shrink();
                    }

                    return SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 680),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                latestAssistant.content,
                                style: const TextStyle(fontSize: 16, height: 1.3),
                              ),
                              if (latestAssistant.choices.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: latestAssistant.choices
                                        .map((c) => OutlinedButton(
                                              onPressed: () => _send(c),
                                              child: Text(c),
                                            ))
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '세계관/캐릭터/행동을 입력하세요...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: game.isLoading ? null : () => _send(_inputController.text.trim()),
                      icon: game.isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _send(String text) async {
    if (text.isEmpty) return;
    _inputController.clear();
    await context.read<GameProvider>().sendUserInput(text);
  }
}


