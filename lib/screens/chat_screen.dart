import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/chat_message.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/typewriter_hint_text.dart';
import 'voice_chat_screen.dart';
import '../widgets/animated_phrase_carousel.dart';

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

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;

  // For custom menus
  final GlobalKey _historyMenuKey = GlobalKey();
  final GlobalKey _conversationMenuKey = GlobalKey();
  OverlayEntry? _historyOverlayEntry;
  OverlayEntry? _conversationOverlayEntry;
  bool _isHistoryMenuOpen = false;
  bool _isConversationMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: widget.apiKey);
    _chat = _model.startChat();

    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10));
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.blueAccent, end: Colors.cyanAccent)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.cyanAccent, end: Colors.purpleAccent)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.purpleAccent, end: Colors.orangeAccent)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.orangeAccent, end: Colors.blueAccent)
            .chain(CurveTween(curve: Curves.easeInOut)),
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

    _initSpeech();
  }

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phraseTimer.cancel();
    _closeHistoryMenu(); 
    _closeConversationMenu();
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
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSendMessage({bool isVoiceInput = false}) async {
    if (_textController.text.isEmpty && _imageFile == null) return;

    final userMessage = ChatMessage(
      text: _textController.text,
      isUser: true,
      timestamp: DateTime.now(),
      imageUrl: _imageFile?.path,
    );
    final text = _textController.text;
    _textController.clear();

    if (_messages.isEmpty) {
      setState(() {});
    }

    _messages.insert(0, userMessage);
    _listKey.currentState
        ?.insertItem(0, duration: const Duration(milliseconds: 300));
    setState(() {
      _isTyping = true;
    });

    try {
      final content = <Part>[];
      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        content.add(DataPart('image/jpeg', imageBytes));
      }
      content.add(TextPart(
          "System instruction: Your responses must be in Spanish, regardless of the language of the prompt. \n\n$text"));
      final response = await _chat.sendMessage(Content.multi(content));
      final aiMessage = ChatMessage(
        text: response.text ?? '...',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.insert(0, aiMessage);
      _listKey.currentState
          ?.insertItem(0, duration: const Duration(milliseconds: 300));
      if (isVoiceInput && response.text != null) {
        _speak(response.text!);
      }
    } catch (e) {
      print('Error sending message: $e');
      final errorMessage = ChatMessage(
        text: 'Error, por favor intenta de nuevo',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _messages.insert(0, errorMessage);
      _listKey.currentState
          ?.insertItem(0, duration: const Duration(milliseconds: 300));
    } finally {
      setState(() {
        _isTyping = false;
        _imageFile = null;
      });
    }
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) => setState(() {
            _textController.text = result.recognizedWords;
          }),
        );
      }
    }
  }

  void _stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
      _handleSendMessage(isVoiceInput: true);
    }
  }

  void _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _toggleHistoryMenu() {
    if (_isHistoryMenuOpen) {
      _closeHistoryMenu();
    } else {
      _openHistoryMenu();
    }
  }

  void _openHistoryMenu() {
    final renderBox = _historyMenuKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _historyOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeHistoryMenu,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: offset.dy + size.height,
              left: offset.dx,
              width: 240,
              child: Material(
                color: const Color(0xFF1E1E1E),
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(
                      title: Text('Historial de chats (Próximamente)', style: TextStyle(color: Colors.white54)),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    ListTile(
                      leading: const Icon(Icons.arrow_forward, color: Colors.white),
                      title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeHistoryMenu();
                        _googleSignIn.signOut();
                        FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_historyOverlayEntry!);
    setState(() {
      _isHistoryMenuOpen = true;
    });
  }

  void _closeHistoryMenu() {
    if (_isHistoryMenuOpen) {
      _historyOverlayEntry?.remove();
      setState(() {
        _isHistoryMenuOpen = false;
      });
    }
  }

  void _toggleConversationMenu() {
    if (_isConversationMenuOpen) {
      _closeConversationMenu();
    } else {
      _openConversationMenu();
    }
  }

  void _openConversationMenu() {
    final renderBox = _conversationMenuKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _conversationOverlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeConversationMenu,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: offset.dy + size.height,
              left: offset.dx - 200 + size.width,
              width: 240,
              child: Material(
                color: const Color(0xFF1E1E1E),
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.share_outlined, color: Colors.white),
                      title: const Text('Compartir', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeConversationMenu();
                        print('Compartir Tapped');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined, color: Colors.white),
                      title: const Text('Cambiar nombre', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeConversationMenu();
                        print('Cambiar nombre Tapped');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.archive_outlined, color: Colors.white),
                      title: const Text('Archivar', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeConversationMenu();
                        print('Archivar Tapped');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      title: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                      onTap: () {
                        _closeConversationMenu();
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Eliminar Chat'),
                              content: const Text(
                                  '¿Estás seguro de que quieres eliminar la conversación actual?'),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    final int count = _messages.length;
                                    for (int i = 0; i < count; i++) {
                                      _listKey.currentState?.removeItem(0,
                                          (context, animation) =>
                                              _buildAnimatedItem(context, 0, animation));
                                    }
                                    _messages.clear();
                                    setState(() {});
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined, color: Colors.white),
                      title: const Text('Informar', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeConversationMenu();
                        print('Informar Tapped');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_conversationOverlayEntry!);
    setState(() {
      _isConversationMenuOpen = true;
    });
  }

  void _closeConversationMenu() {
    if (_isConversationMenuOpen) {
      _conversationOverlayEntry?.remove();
      setState(() {
        _isConversationMenuOpen = false;
      });
    }
  }

  bool get _hasStartedChat => _messages.isNotEmpty;

  Widget _buildAnimatedItem(
      BuildContext context, int index, Animation<double> animation) {
    final message = _messages[index];

    final scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      ),
    );

    final slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.5), end: Offset.zero).animate(
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
            onSpeak: (text) => _speak(text),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildInitialAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0C0C0C),
      elevation: 0,
      leading: IconButton(
        key: _historyMenuKey,
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: _toggleHistoryMenu,
      ),
      title: TextButton.icon(
        onPressed: () {},
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF3A416F),
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
        label: const Text(
          'Obtener Plus',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  PreferredSizeWidget _buildConversationAppBar() {
    return AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            // Eventually, this will open the drawer with the chat history
          },
        ),
        title: const Text('Selene'),
        actions: [
          IconButton(
            key: _conversationMenuKey,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _toggleConversationMenu,
          )
        ]);
  }

  @override
  Widget build(BuildContext context) {
    String? firstName = user?.displayName?.split(' ').first ?? 'amigo';

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: _messages.isEmpty ? _buildInitialAppBar() : _buildConversationAppBar(),
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
                        const SizedBox(height: 3),
                        const AnimatedPhraseCarousel(),
                        const SizedBox(height: 15),
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
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
                  hintText: null,
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  hint: _textController.text.isEmpty
                      ? const TypewriterHintText(
                          phrases: [
                            '¿Cuál es el sentido de la vida?',
                            '¿Qué es un agujero negro?',
                            'Escribe un poema sobre el amor.',
                            '¿Cuál es la capital de Mongolia?',
                          ],
                        )
                      : null,
                ),
                onChanged: (text) {
                  setState(() {});
                },
                onSubmitted: (value) => _handleSendMessage(isVoiceInput: false),
              ),
            ),
            GestureDetector(
              onTapDown: (_) => _startListening(),
              onTapUp: (_) => _stopListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white54,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white54),
              onPressed: () => _handleSendMessage(isVoiceInput: false),
            ),
          ],
        ),
      ),
    );
  }
}
