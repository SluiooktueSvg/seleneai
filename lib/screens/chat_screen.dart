
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/chat_message.dart';
import '../widgets/chat_message_bubble.dart';
import 'voice_chat_screen.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn();

class ChatScreen extends StatefulWidget {
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
  File? _imageFile;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  late final AnimationController _animationController;
  late final Animation<Color?> _colorAnimation;

  // For animated phrases
  late final Timer _phraseTimer;
  int _currentPhraseIndex = 0;
  final List<String> _phrases = [
    '¿En qué puedo ayudarte a pensar o resolver?',
    '¿Listo para crear algo increíble?',
    'Pregúntame lo que sea.',
    '¿Cómo puedo potenciar tu día?',
    'Vamos a explorar nuevas ideas juntos.',
  ];

  @override
  void initState() {
    super.initState();
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
    _animationController.repeat(reverse: true);

    _phraseTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentPhraseIndex = (_currentPhraseIndex + 1) % _phrases.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phraseTimer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    } else if (hour < 19) {
      return 'Buenas tardes';
    } else {
      return 'Buenas noches';
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSendMessage() async {
    if (_textController.text.isEmpty && _imageFile == null) return;

    final userMessage = ChatMessage(
      text: _textController.text,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: _imageFile?.path,
    );
    final text = _textController.text;
    _textController.clear();

    _messages.insert(0, userMessage);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    setState(() {
      _isTyping = true;
    });

    try {
      final content = <Part>[];
      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        content.add(DataPart('image/jpeg', imageBytes));
      }
      content.add(TextPart("System instruction: Your responses must be in Spanish, regardless of the language of the prompt. \n\n$text"));
      final response = await _chat.sendMessage(Content.multi(content));
      final aiMessage = ChatMessage(
        text: response.text ?? '...',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.insert(0, aiMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    } catch (e) {
      print('Error sending message: $e');
      final errorMessage = ChatMessage(
        text: 'Error, por favor intenta de nuevo',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.insert(0, errorMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    } finally {
       setState(() {
        _isTyping = false;
        _imageFile = null;
      });
    }
  }

  bool get _hasStartedChat => _messages.isNotEmpty;

  Widget _buildAnimatedItem(BuildContext context, int index, Animation<double> animation) {
    final message = _messages[index];
    
    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      ),
    );

    final slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      ),
    );

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
      child: SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: ChatMessageBubble(
            key: ObjectKey(message),
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
                onTap: _pickImage,
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
                              '${_getGreeting()}, $firstName',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _colorAnimation.value,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40, // Increased height to prevent overflow
                          child: ClipRect(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                final isEntering = (child.key as ValueKey<int>).value == _currentPhraseIndex;
                                
                                final startOffset = isEntering ? const Offset(0.0, 1.0) : const Offset(0.0, 0.0);
                                final endOffset = isEntering ? const Offset(0.0, 0.0) : const Offset(0.0, -1.0);

                                final tween = Tween<Offset>(begin: startOffset, end: endOffset);
                                final slideAnimation = animation.drive(tween.chain(CurveTween(curve: Curves.easeInOut)));

                                return SlideTransition(
                                  position: slideAnimation,
                                  child: child,
                                );
                              },
                              child: Text(
                                _phrases[_currentPhraseIndex],
                                key: ValueKey<int>(_currentPhraseIndex),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: Colors.white70),
                              ),
                            ),
                          ),
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
