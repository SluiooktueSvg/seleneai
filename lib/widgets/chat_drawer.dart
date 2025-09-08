import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:selene/models/conversation.dart';

class ChatDrawer extends StatelessWidget {
  final User? user;
  final List<Conversation> conversations;
  final VoidCallback onNewChat;
  final VoidCallback onSignOut;
  final Function(Conversation) onLoadConversation;

  const ChatDrawer({
    super.key,
    required this.user,
    required this.conversations,
    required this.onNewChat,
    required this.onSignOut,
    required this.onLoadConversation,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0C0C0C),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, color: Colors.white54),
                          hintText: 'Buscar',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: onNewChat,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: const Text('Nuevo chat', style: TextStyle(color: Colors.white)),
              onTap: onNewChat,
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined, color: Colors.white),
              title: const Text('Biblioteca', style: TextStyle(color: Colors.white)),
              onTap: () { /* No action yet */ },
            ),
            ListTile(
              leading: const Icon(Icons.apps_outlined, color: Colors.white),
              title: const Text('GPT', style: TextStyle(color: Colors.white)),
              onTap: () { /* No action yet */ },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined, color: Colors.white),
              title: Row(
                children: [
                  const Text('Proyectos', style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A416F),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: const Text(
                      'NUEVO',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              onTap: () { /* No action yet */ },
            ),
            Expanded(
              child: conversations.isEmpty
                  ? const Center(
                      child: Text(
                        'Aquí se mostrará tu historial de chats.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                          title: Text(
                            conversation.title,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onLoadConversation(conversation),
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(user?.displayName ?? 'Usuario', style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: onSignOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
