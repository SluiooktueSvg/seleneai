import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

import 'voice_chat_screen.dart';

// Create a single, top-level instance of GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn();

// The API key is now loaded from .env

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Load the environment variables
  await dotenv.load(fileName: ".env");
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
    // Retrieve the API key safely
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
            // Pass the API key to ChatScreen
            return ChatScreen(apiKey: apiKey);
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
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  // Receive the API key
  final String apiKey;
  const ChatScreen({super.key, required this.apiKey});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
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
    // Use the apiKey from the widget
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: widget.apiKey);
    _chat = _model.startChat();

    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.blueAccent, end: Colors.cyanAccent).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.cyanAccent, end: Colors.purpleAccent).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.purpleAccent, end: Colors.orangeAccent).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.orangeAccent, end: Colors.blueAccent).chain(CurveTween(curve: Curves.easeInOut)),
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

    final userMessage = ChatMessage(
      text: _textController.text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    final text = _textController.text;
    _textController.clear();

    // Insert user message
    _messages.insert(0, userMessage);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    setState(() {
      _isTyping = true;
    });

    try {
      final response = await _chat.sendMessage(Content.text("System instruction: Your responses must be in Spanish, regardless of the language of the prompt. \n\n$text"));
      final aiMessage = ChatMessage(
        text: response.text ?? '...',
        isUser: false,
        timestamp: DateTime.now(),
      );
      // Insert AI message
      _messages.insert(0, aiMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    } catch (e) {
      print('Error sending message: $e');
      final errorMessage = ChatMessage(
        text: 'Error, por favor intenta de nuevo',
        isUser: false,
        timestamp: DateTime.now(),
      );
      // Insert error message
      _messages.insert(0, errorMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    } finally {
       setState(() {
        _isTyping = false;
      });
    }
  }

  bool get _hasStartedChat => _messages.isNotEmpty;

  Widget _buildAnimatedItem(BuildContext context, int index, Animation<double> animation) {
    final message = _messages[index];
    
    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack, // Use easeOutBack for a subtle bounce
      ),
    );

    final slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      ),
    );

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn), // Smoother fade-in
      child: SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: _ChatMessageBubble(
            key: ObjectKey(message), // Important for performance
            message: message,
            userPhotoUrl: user?.photoURL,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? firstName = user?.displayName?.split(' ').first ?? 'amigo';
    final apiKey = dotenv.env['GEMINI_API_KEY']!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bubble_chart, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'Selene',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 16),
            Image.asset('assets/images/google_logo.png', height: 16.0),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          color: const Color(0xFF1E1E1E),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Color(0xFF0C0C0C),
                ),
                child: Text(
                  'Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.graphic_eq, color: Colors.white),
                title: const Text('Real-time chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VoiceChatScreen(apiKey: apiKey)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_copy_outlined, color: Colors.white),
                title: const Text('Copy File', style: TextStyle(color: Colors.white)),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: Colors.white),
                title: const Text('Folder', style: TextStyle(color: Colors.white)),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  // Show a confirmation dialog before deleting the chat history
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Chat'),
                        content: const Text('Are you sure you want to delete the current conversation?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              // Clear the list and update the AnimatedList
                              final int count = _messages.length;
                              for (int i = 0; i < count; i++) {
                                _listKey.currentState?.removeItem(0, (context, animation) => _buildAnimatedItem(context, 0, animation));
                              }
                              _messages.clear();
                              setState((){});
                              Navigator.of(context).pop();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward, color: Colors.white),
                title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  // Sign out from Google and Firebase
                  await _googleSignIn.signOut();
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
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
                : AnimatedList(
                    key: _listKey,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    initialItemCount: _messages.length,
                    itemBuilder: _buildAnimatedItem,
                  ),
          ),
          if (_hasStartedChat) _buildTextComposer(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '© 2025 Selene. All rights reserved. SeleneAI.',
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

// _ChatMessageBubble is now a stateless widget, as animations are handled by AnimatedList
class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    super.key,
    required this.message,
    this.userPhotoUrl,
    this.isTyping = false,
  });

  final ChatMessage message;
  final String? userPhotoUrl;
  final bool isTyping;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final timeString = timeFormat.format(message.timestamp);

    final aiAvatar = CircleAvatar(
      backgroundColor: Colors.blue.shade900,
      child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 14)),
    );

    final userAvatar = CircleAvatar(
      backgroundImage: userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
      child: userPhotoUrl == null ? const Icon(Icons.person) : null,
    );

    final messageBubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: message.isUser ? const Color(0xFF2E3A46) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isTyping ? _buildTypingIndicator(timeString) : _buildMessageContent(timeString),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[aiAvatar, const SizedBox(width: 8)],
          messageBubble,
          if (message.isUser) ...[const SizedBox(width: 8), userAvatar],
        ],
      ),
    );
  }

  Widget _buildMessageContent(String timeString) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.isNotEmpty)
          Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Changed this line
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              timeString,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (!message.isUser)
              ...[
                const SizedBox(width: 10),
                const Text(
                  'positive',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.volume_up_outlined, color: Colors.white54, size: 16),
              ],
          ],
        ),
      ],
    );
  }

  Widget _buildTypingIndicator(String timeString) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thinking...',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              timeString,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 10),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Analyzing...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.volume_up_outlined, color: Colors.white54, size: 16),
          ],
        ),
      ],
    );
  }
}
