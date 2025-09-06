import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Create a single, top-level instance of GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selene',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
        primaryColor: Colors.blueAccent,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return const ChatScreen();
          }
          return const SignInScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print("Something went wrong with Google Sign-In");
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bubble_chart, size: 40),
                SizedBox(width: 10),
                Text(
                  'Selene',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
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
              icon: Image.network('http://pngimg.com/uploads/google/google_PNG19635.png', height: 24.0),
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
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  bool _hasStartedChat = false;

  late final AnimationController _animationController;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 5));
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
        tween: ColorTween(begin: Colors.purpleAccent, end: Colors.blueAccent),
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

  void _handleSendMessage() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _hasStartedChat = true;
      });
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    String? firstName = user?.displayName?.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.square_outlined, color: Colors.white),
          onPressed: () {},
        ),
        title: Row(
          children: [
            const Icon(Icons.nights_stay_outlined, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Selene', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.mic_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.file_copy_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.folder_outlined, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.white),
            onPressed: () async {
              await _googleSignIn.signOut();
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: !_hasStartedChat
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _colorAnimation,
                          builder: (context, child) {
                            return Text(
                              'Buenos días, ${firstName ?? 'User'}',
                              style: TextStyle(
                                fontSize: 28, // Restored font size
                                color: _colorAnimation.value, // Applied animated color
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '¿En qué puedo ayudarte a pensar o resolver?',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        _buildTextComposer(),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: 0, // Placeholder for chat messages
                    itemBuilder: (context, index) {
                      return const Text('Message'); // Placeholder
                    },
                  ),
          ),
          if (_hasStartedChat) _buildTextComposer(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '© 2025 Selene. All rights reserved. Sluiooktue Inc. Luis M.',
              style: TextStyle(fontSize: 10, color: Colors.white30),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.0),
                  hintText: 'Cuéntame una',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mic, color: Colors.white54),
              onPressed: () {
                // Handle voice input
              },
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white54),
              onPressed: _handleSendMessage, // Updated onPressed
            ),
          ],
        ),
      ),
    );
  }
}
