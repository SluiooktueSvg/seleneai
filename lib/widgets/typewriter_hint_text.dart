import 'dart:async';
import 'package:flutter/material.dart';

class TypewriterHintText extends StatefulWidget {
  final List<String> phrases;
  final Duration typingSpeed;
  final Duration delay;

  const TypewriterHintText({
    super.key,
    required this.phrases,
    this.typingSpeed = const Duration(milliseconds: 100),
    this.delay = const Duration(seconds: 3),
  });

  @override
  _TypewriterHintTextState createState() => _TypewriterHintTextState();
}

class _TypewriterHintTextState extends State<TypewriterHintText> {
  int _phraseIndex = 0;
  int _charIndex = 0;
  String _displayedText = '';
  Timer? _typingTimer;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTyping() {
    _typingTimer = Timer.periodic(widget.typingSpeed, (timer) {
      if (!mounted) return;
      setState(() {
        String currentPhrase = widget.phrases[_phraseIndex];
        if (_isDeleting) {
          if (_charIndex > 0) {
            _charIndex--;
            _displayedText = currentPhrase.substring(0, _charIndex);
          } else {
            _isDeleting = false;
            _phraseIndex = (_phraseIndex + 1) % widget.phrases.length;
            _typingTimer?.cancel();
            Timer(widget.delay, _startTyping);
          }
        } else {
          if (_charIndex < currentPhrase.length) {
            _charIndex++;
            _displayedText = currentPhrase.substring(0, _charIndex);
          } else {
            _isDeleting = true;
            _typingTimer?.cancel();
            Timer(widget.delay, _startTyping);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      key: ValueKey<String>(_displayedText),
      style: const TextStyle(color: Colors.white54),
    );
  }
}
