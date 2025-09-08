
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import 'rgb_loader.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
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
      child: isTyping ? _buildTypingIndicator(timeString) : _buildMessageContent(timeString, context),
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

  Widget _buildMessageContent(String timeString, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.imageUrl != null)
          Image.file(File(message.imageUrl!)),
        if (message.text.isNotEmpty)
          Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeString,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (!message.isUser) ...[
              const SizedBox(width: 10),
              const Text(
                'positive',
                style: TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.volume_up_outlined, color: Colors.white54, size: 14),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildTypingIndicator(String timeString) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RgbLoader(),
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
            const Text(
              'Analyzing...',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
