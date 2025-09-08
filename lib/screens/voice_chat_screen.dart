import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// API Key is now passed from the main screen.

class VoiceChatScreen extends StatefulWidget {
  final String apiKey;
  const VoiceChatScreen({super.key, required this.apiKey});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  late final GenerativeModel _model;

  bool _isListening = false;
  String _userText = 'Press the button to start the conversation';
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    // Use the apiKey from the widget
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: widget.apiKey);
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _userText = "Listening...";
        });
        _listen();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _userText, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, color: Colors.white, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 30),
              Text(
                _aiResponse, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        tooltip: 'Listen',
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _aiResponse = ''; // Clear previous AI response
          _userText = 'Listening...';
        });
        _speechToText.listen(
          onResult: (val) {
            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              setState(() {
                _userText = val.recognizedWords;
                _isListening = false;
              });
              _speechToText.stop();
              _sendToAI(_userText);
            }
          },
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  void _sendToAI(String message) async {
    setState(() {
      _aiResponse = 'Thinking...';
    });
    try {
      final response = await _model.generateContent([Content.text(message)]);
      final responseText = response.text ?? 'Sorry, I could not understand.';
      setState(() {
        _aiResponse = responseText;
      });
      _speak(responseText);
    } catch (e) {
      print('Error sending message to AI: $e');
      setState(() {
        _aiResponse = 'Error, please try again';
      });
    }
  }

  void _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }
}
