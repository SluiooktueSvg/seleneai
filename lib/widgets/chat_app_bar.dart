
import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isChatEmpty;
  final VoidCallback onStartNewChat;
  final VoidCallback openDrawer;
  final GlobalKey historyMenuKey;
  final VoidCallback toggleHistoryMenu;
  final GlobalKey conversationMenuKey;
  final VoidCallback toggleConversationMenu;

  const ChatAppBar({
    super.key,
    required this.isChatEmpty,
    required this.onStartNewChat,
    required this.openDrawer,
    required this.historyMenuKey,
    required this.toggleHistoryMenu,
    required this.conversationMenuKey,
    required this.toggleConversationMenu,
  });

  @override
  Widget build(BuildContext context) {
    return isChatEmpty ? _buildInitialAppBar() : _buildConversationAppBar(context);
  }

  PreferredSizeWidget _buildInitialAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0C0C0C),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        onPressed: () {},
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
          key: historyMenuKey,
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: toggleHistoryMenu,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildConversationAppBar(BuildContext context) {
    return AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: openDrawer,
        ),
        title: const Text('Selene'),
        actions: [
          IconButton(
            key: conversationMenuKey,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: toggleConversationMenu,
          )
        ]);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
