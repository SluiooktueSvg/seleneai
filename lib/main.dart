import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Create a single, top-level instance of GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn();

// IMPORTANT: Replace with your actual API key
const String apiKey = 'YOUR_API_KEY';

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
      debugShowCheckedModeBanner: false, // Hiding the debug banner
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

class ChatMessage {
  final String text;
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  late final AnimationController _animationController;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    _chat = _model.startChat();

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

  Future<void> _handleSendMessage() async {
    if (_textController.text.isEmpty) return;

    final userMessage = ChatMessage(text: _textController.text, isUser: true);
    _textController.clear();

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text(userMessage.text));
      final aiMessage = ChatMessage(text: response.text ?? '...', isUser: false);
      setState(() {
        _messages.add(aiMessage);
      });
    } catch (e) {
      print('Error sending message: $e');
      final errorMessage = ChatMessage(text: 'Error, por favor intenta de nuevo', isUser: false);
      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
       setState(() {
        _isTyping = false;
      });
    }
  }

  bool get _hasStartedChat => _messages.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    String? firstName = user?.displayName?.split(' ').first ?? 'amigo';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.square_outlined, color: Colors.white),
          onPressed: () {},
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nights_stay, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Selene', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, size: 20),
                    onPressed: () {},
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.graphic_eq, size: 20),
                    onPressed: () {},
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.file_copy_outlined, size: 20),
                    onPressed: () {},
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.folder_outlined, size: 20),
                    onPressed: () {},
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {},
                    color: Colors.redAccent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    onPressed: () async {
                      await _googleSignIn.signOut();
                      await FirebaseAuth.instance.signOut();
                    },
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
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
                              'Buenos días, $firstName',
                              style: TextStyle(
                                fontSize: 28,
                                color: _colorAnimation.value,
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
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    reverse: true,
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping && index == 0) {
                        return const _ChatMessageBubble(message: ChatMessage(text: '...', isUser: false));
                      }
                      final messageIndex = _isTyping ? index -1 : index;
                      final message = _messages.reversed.toList()[messageIndex];
                      return _ChatMessageBubble(message: message);
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
                  hintText: 'Explore',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) => _handleSendMessage(),
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
              onPressed: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blueAccent : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
