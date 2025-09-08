
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/sign_in_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/loading_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
        return const Scaffold(
            body: Center(
                child: Text('Error: API Key is not configured. Please check your .env file.'),
            ),
        );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return ChatScreen(apiKey: apiKey);
          }
          return const SignInScreen();
        }
        return const LoadingScreen();
      },
    );
  }
}
