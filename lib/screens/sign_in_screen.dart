
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'loading_screen.dart';

// Create a single, top-level instance of GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn();

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() async {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If the user cancels the sign-in, stop the loading indicator
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Let the AuthWrapper handle the navigation
      await FirebaseAuth.instance.signInWithCredential(credential);    } catch (e) {
      print("Something went wrong with Google Sign-In: $e");
      // Stop loading if there is an error
      if (mounted) setState(() => _isLoading = false);
    }
    } catch (e) {
      print("Something went wrong with Google Sign-In: $e");
      // Stop loading if there is an error
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOutGoogle() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FittedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bubble_chart, size: 40),
                      const SizedBox(width: 10),
                      const Text(
                        'Selene',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      Image.asset('assets/images/google_logo.png', height: 24.0),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Selene',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign in to start chatting with the AI.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: Image.asset('assets/images/google_logo.png', height: 24.0),
                  label: const Text('Sign In with Google'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black, backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const LoadingScreen(),
        ],
      ),
    );
  }
}
