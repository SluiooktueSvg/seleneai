import 'dart:convert';
import 'package:selene/models/chat_message.dart';

class Conversation {
  final String id;
  String title;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'],
        messages: (json['messages'] as List)
            .map((messageJson) => ChatMessage.fromJson(messageJson))
            .toList(),
      );
}
