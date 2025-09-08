
import 'package:flutter/material.dart';

class RgbLoader extends StatefulWidget {
  const RgbLoader({super.key});

  @override
  State<RgbLoader> createState() => _RgbLoaderState();
}

class _RgbLoaderState extends State<RgbLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.blueAccent, end: Colors.cyanAccent),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.cyanAccent, end: Colors.purpleAccent),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.purpleAccent, end: Colors.orangeAccent),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.orangeAccent, end: Colors.redAccent),
        weight: 1.0,
      ),
       TweenSequenceItem(
        tween: ColorTween(begin: Colors.redAccent, end: Colors.blueAccent),
        weight: 1.0,
      ),
    ]).animate(_animationController);
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Text(
          '[ = = = ]',
          style: TextStyle(
            color: _colorAnimation.value,
            fontSize: 24,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }
}
