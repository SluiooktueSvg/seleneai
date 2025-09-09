import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:selene/models/conversation.dart';
import 'package:selene/services/storage_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/chat_message.dart';
import '../widgets/chat_drawer.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final TextEditingController _textController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  
  // State for conversations
  final StorageService _storageService = StorageService();
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  late final GenerativeModel _model;
  late ChatSession _chat;

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
  bool _isListening = false;

  // For custom menus
  final GlobalKey _historyMenuKey = GlobalKey();
  final GlobalKey _conversationMenuKey = GlobalKey();
  OverlayEntry? _historyOverlayEntry;
  OverlayEntry? _conversationOverlayEntry;
  bool _isHistoryMenuOpen = false;
  bool _isConversationMenuOpen = false;

  // Voice Chat State
  bool _isVoiceChatActive = false;
  String _voiceChatStatus = "Toca para hablar";
  late final AnimationController _voiceAnimationController;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-pro', apiKey: widget.apiKey);
    _chat = _model.startChat();
    _loadConversations();

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
     _voiceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
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
    _voiceAnimationController.dispose();
    super.dispose();
  }
  
  Future<void> _handleSignOut() async {
    // Close the drawer before signing out
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    setState(() {
      _conversations = [];
      _currentConversation = null;
      _messages.clear();
    });
    // Assuming StorageService has a clearConversations method
    await _storageService.clearConversations(user!.uid);
  }

  Future<void> _loadConversations() async {
    final conversations = await _storageService.loadConversations();
    setState(() {
      _conversations = conversations;
    });
  }

  void _startNewChat() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    } 
    
    setState(() {
      _currentConversation = null;
      final int count = _messages.length;
      for (int i = 0; i < count; i++) {
        _listKey.currentState?.removeItem(
          0, 
          (context, animation) => _buildAnimatedItem(context, 0, animation, _messages[0]),
          duration: const Duration(milliseconds: 200)
        );
      }
      _messages.clear();
      _chat = _model.startChat();
    });
  }
  
  void _loadConversation(Conversation conversation) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    } 
    
    setState(() {
      _currentConversation = conversation;
      _messages.clear();
      _messages.addAll(conversation.messages);
      _chat = _model.startChat(history: conversation.messages.where((m) => m.text.isNotEmpty).map((m) {
        return m.isUser ? Content.text(m.text) : Content.model([TextPart(m.text)]);
      }).toList());
    });
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

  Future<void> _handleSendMessage({String? text}) async {
    final messageText = text ?? _textController.text;
    if (messageText.isEmpty) return;

    _textController.clear();

    if (_currentConversation == null) {
      final newConversationId = DateTime.now().millisecondsSinceEpoch.toString();
      final title = messageText.length > 30 ? messageText.substring(0, 30) : messageText;
      _currentConversation = Conversation(id: newConversationId, title: title, messages: []);
      _conversations.insert(0, _currentConversation!);
    }

    final userMessage = ChatMessage(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      conversationId: _currentConversation!.id,
    );
    
    _currentConversation!.messages.insert(0, userMessage);
    if (_messages.isEmpty) {
      setState(() {}); 
    }
    _messages.insert(0, userMessage);
    _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    
    setState(() {
      _isTyping = true;
    });

    try {
      final content = [TextPart("System instruction: Your responses must be in Spanish, regardless of the language of the prompt. \n\n$messageText")];
     
      final response = await _chat.sendMessage(Content.multi(content));
      final aiMessage = ChatMessage(
        text: response.text ?? '...',
        isUser: false,
        timestamp: DateTime.now(),
        conversationId: _currentConversation!.id,
      );
      _currentConversation!.messages.insert(0, aiMessage);
      _messages.insert(0, aiMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));

    } catch (e) {
      print('Error sending message: $e');
      final errorMessage = ChatMessage(
        text: 'Error, por favor intenta de nuevo',
        isUser: false,
        timestamp: DateTime.now(),
        conversationId: _currentConversation!.id,
      );
      _currentConversation!.messages.insert(0, errorMessage);
      _messages.insert(0, errorMessage);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    } finally {
      await _storageService.saveConversation(user!.uid, _currentConversation!); // Save the updated conversation
        _isTyping = false;
      });
      _loadConversations();
    }
  }

  void _handleVoiceMessage() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _handleSendMessage(text: result.recognizedWords);
              setState(() => _isListening = false);
              _speechToText.stop();
            }
          },
        );
      } 
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }
  
  void _toggleVoiceChat() {
    setState(() {
      _isVoiceChatActive = !_isVoiceChatActive;
    });
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
                      leading: const Icon(Icons.graphic_eq, color: Colors.white),
                      title: const Text('Real-time chat', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _closeHistoryMenu();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VoiceChatScreen(apiKey: widget.apiKey),
                          ),
                        );
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
                        _renameConversation();
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
                                     if (_currentConversation != null) {
                                      _storageService.deleteConversation(user!.uid, _currentConversation!.id);
                                    }
                                    _startNewChat();
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

  void _renameConversation() {
    if (_currentConversation == null) return;

    final TextEditingController renameController =
        TextEditingController(text: _currentConversation!.title);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar nombre del chat'),
          content: TextField(
            controller: renameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nuevo nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (renameController.text.isNotEmpty) {
                  final newTitle = renameController.text;
                  setState(() {
                    _currentConversation!.title = newTitle;
                  });
                  await _storageService.saveConversation(user!.uid, _currentConversation!);
                  _loadConversations();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  bool get _hasStartedChat => _messages.isNotEmpty;

  Widget _buildAnimatedItem(
      BuildContext context, int index, Animation<double> animation, ChatMessage message) {

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
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
           _scaffoldKey.currentState?.openDrawer();
        },
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
          icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
          onPressed: _startNewChat,
        ),
        IconButton(
          key: _historyMenuKey,
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: _toggleHistoryMenu,
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
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(_currentConversation?.title ?? 'Selene'),
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
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: _messages.isEmpty ? _buildInitialAppBar() : _buildConversationAppBar(),
      drawer: ChatDrawer(
        user: user,
        conversations: _conversations,
        onNewChat: _startNewChat,
        onSignOut: _handleSignOut,
        onLoadConversation: _loadConversation,
      ),
      body: Stack(
        children: [
          Column(
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
                        itemBuilder: (context, index, animation) {
                          final message = _messages[index];
                          return _buildAnimatedItem(context, index, animation, message);
                        },
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
          if (_isVoiceChatActive) _buildVoiceChatOverlay(),
        ],
      ),
    );
  }
  
   Widget _buildVoiceChatOverlay() {
    return GestureDetector(
      onTap: _toggleVoiceChat,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isListening ? () {} : _handleVoiceMessage,
                child: AnimatedBuilder(
                  animation: _voiceAnimationController,
                  builder: (context, child) {
                    final double size = _isListening ? 150.0 + _voiceAnimationController.value * 30 : 150.0;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24,
                        border: Border.all(
                          color: _isListening ? Colors.cyanAccent : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 80,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(_voiceChatStatus, style: const TextStyle(color: Colors.white54, fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    bool hasText = _textController.text.isNotEmpty;

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
                onSubmitted: (value) => hasText ? _handleSendMessage() : null,
              ),
            ),
            IconButton(
                icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white54),
                onPressed: _handleVoiceMessage,
            ),
            hasText
              ? IconButton(
                  icon: const Icon(Icons.send, color: Colors.white54),
                  onPressed: () => _handleSendMessage(),
                )
              : IconButton(
                  icon: const Icon(Icons.graphic_eq, color: Colors.white54),
                  onPressed: _toggleVoiceChat,
                ),
          ],
        ),
      ),
    );
  }
}
