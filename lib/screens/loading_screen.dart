
import 'package:flutter/material.dart';
import '../widgets/rgb_loader.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0C0C0C),
      body: Center(
        child: RgbLoader(),
      ),
    );
  }
}
