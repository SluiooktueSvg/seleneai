import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// IMPORTANT: Replace with your actual API key
const String apiKey = 'AIzaSyDE6EX2yL5yJLEBNv6nZ84jK-BZwtfHidw';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final GenerativeModel _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);

  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_text, style: const TextStyle(fontSize: 24, color: Colors.white)),
            const SizedBox(height: 20),
            Text(_aiResponse, style: const TextStyle(fontSize: 20, color: Colors.greenAccent)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.finalResult) {
              _isListening = false;
              _sendToAI(_text);
            }
          }),
        );
      } 
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  void _sendToAI(String message) async {
    try {
      final response = await _model.generateContent([Content.text(message)]);
      setState(() {
        _aiResponse = response.text ?? '...';
        _speak(_aiResponse);
      });
    } catch (e) {
      print('Error sending message to AI: $e');
      setState(() {
        _aiResponse = 'Error, please try again';
      });
    }
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }
}
