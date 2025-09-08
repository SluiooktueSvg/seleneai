import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceChatScreen extends StatefulWidget {
  final String apiKey;
  const VoiceChatScreen({super.key, required this.apiKey});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> with TickerProviderStateMixin {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  String _spokenText = '';
  String _aiResponse = '';
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isAiSpeaking = false;
  bool _conversationStarted = false;

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-pro', apiKey: widget.apiKey);
    _chat = _model.startChat();
    _initSpeech();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isAiSpeaking = false;
        });
        _startListening(); // Listen for the next user input after AI finishes speaking
      }
    });
  }

  void _startListening() {
    if (!_isListening && !_isAiSpeaking && mounted) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            final recognizedWords = result.recognizedWords.toLowerCase();
            if (!_conversationStarted) {
              if (recognizedWords.contains('hola')) {
                _startConversation();
              }
            } else {
              _handleSpeechResult(recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 10),
        onDevice: true,
        cancelOnError: true,
        partialResults: false,
      );
    }
  }

  void _startConversation() {
    setState(() {
      _conversationStarted = true;
      _spokenText = 'Hola, ¿en qué puedo ayudarte?'; // Initial prompt
    });
    _speak(_spokenText);
  }

  void _stopListening() {
    if (_isListening && mounted) {
      _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _handleSpeechResult(String text) async {
    _stopListening();
    if (text.isEmpty) return;

    setState(() {
      _spokenText = text;
      _isProcessing = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final aiText = response.text ?? '...';
      setState(() {
        _aiResponse = aiText;
      });
      _speak(aiText);
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _aiResponse = 'Lo siento, ha ocurrido un error.';
      });
      _speak(_aiResponse);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _speak(String text) async {
    if (mounted) {
      setState(() {
        _isAiSpeaking = true;
      });
      await _flutterTts.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Real-time Chat', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildMicrophone(),
            const SizedBox(height: 20),
            _buildStatusText(),
            if (_spokenText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Tú: $_spokenText',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_aiResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Selene: $_aiResponse',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    String statusText;
    if (!_conversationStarted) {
      statusText = "Di 'Hola' para empezar";
    } else if (_isListening) {
      statusText = 'Escuchando...';
    } else if (_isProcessing) {
      statusText = 'Procesando...';
    } else if (_isAiSpeaking) {
      statusText = 'Hablando...';
    } else {
      statusText = 'Toca para hablar';
    }
    return Text(statusText, style: const TextStyle(color: Colors.white54, fontSize: 18));
  }

  Widget _buildMicrophone() {
    return GestureDetector(
      onTap: _conversationStarted ? _startListening : null,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final double size = _isListening ? 150.0 + _animationController.value * 30 : 150.0;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24,
              border: Border.all(
                color: _isListening ? Colors.cyanAccent : Colors.transparent,
                width: 2.0,
              ),
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 80,
            ),
          );
        },
      ),
    );
  }
}
