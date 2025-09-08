import 'dart:async';
import 'package:flutter/material.dart';


class AnimatedPhraseCarousel extends StatefulWidget {
  const AnimatedPhraseCarousel({super.key});

  @override
  State<AnimatedPhraseCarousel> createState() => _AnimatedPhraseCarouselState();
}

class _AnimatedPhraseCarouselState extends State<AnimatedPhraseCarousel> {
  final List<String> _phrases = [
    '¿En qué puedo ayudarte a pensar o resolver?',
    '¿Listo para crear algo increíble?',
    'Pregúntame lo que sea.',
    '¿Cómo puedo potenciar tu día?',
    'Vamos a explorar nuevas ideas juntos.',
  ];

  late PageController _pageController;
  late Timer _phraseTimer;
  int _currentPhraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _phraseTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final nextPage = (_currentPhraseIndex + 1) % _phrases.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPhraseIndex = nextPage;
      });
    });
  }

  @override
  void dispose() {
    _phraseTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40, // espacio fijo
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _phrases.length,
        itemBuilder: (context, index) {
          return Center(
            child: Text(
              _phrases[index],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}
