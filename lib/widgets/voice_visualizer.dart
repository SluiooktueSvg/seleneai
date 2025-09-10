import 'dart:math';
import 'package:flutter/material.dart';

class VoiceVisualizer extends StatefulWidget {
  const VoiceVisualizer({super.key});

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // Initialize with random heights
    for (int i = 0; i < 30; i++) {
      _barHeights.add(_random.nextDouble() * 15 + 2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Animate only a few bars for a more realistic effect
        int animatedBarIndex = _random.nextInt(_barHeights.length);
        _barHeights[animatedBarIndex] = _random.nextDouble() * (10 * _controller.value) + 2;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_barHeights.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.5,
              height: index == animatedBarIndex ? _barHeights[index] : _barHeights[index] * 0.7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
              ),
            );
          }),
        );
      },
    );
  }
}