import 'package:flutter/material.dart';
import '../widgets/typewriter_hint_text.dart';

class TextComposer extends StatelessWidget {
  final TextEditingController textController;
  final bool isListening;
  final VoidCallback onStartListening;
  final VoidCallback onStopListening;
  final Function(String) onSendMessage;
  final VoidCallback onTextChanged;


  const TextComposer({
    super.key,
    required this.textController,
    required this.isListening,
    required this.onStartListening,
    required this.onStopListening,
    required this.onSendMessage,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                  hintText: null,
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  hint: textController.text.isEmpty
                      ? const TypewriterHintText(
                          phrases: [
                            '¿Cuál es el sentido de la vida?',
                            '¿Qué es un agujero negro?',
                            'Escribe un poema sobre el amor.',
                            '¿Cuál es la capital de Mongolia?',
                          ],
                        )
                      : null,
                ),
                onChanged: (text) => onTextChanged(),
                onSubmitted: (value) => onSendMessage(value),
              ),
            ),
            GestureDetector(
              onTapDown: (_) => onStartListening(),
              onTapUp: (_) => onStopListening(),
              onLongPressEnd: (_) => onStopListening(),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white54,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white54),
              onPressed: () => onSendMessage(textController.text),
            ),
          ],
        ),
      ),
    );
  }
}
