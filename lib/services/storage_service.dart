import 'dart:convert';
import 'package:selene/models/conversation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _conversationsKey = 'conversations';

  Future<void> saveConversation(Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await loadConversations();
    final index = conversations.indexWhere((c) => c.id == conversation.id);

    if (index != -1) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }

    final conversationsJson = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_conversationsKey, conversationsJson);
  }

  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final conversationsJson = prefs.getStringList(_conversationsKey) ?? [];
    return conversationsJson
        .map((json) => Conversation.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> deleteConversation(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await loadConversations();
    conversations.removeWhere((c) => c.id == conversationId);
    final conversationsJson = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_conversationsKey, conversationsJson);
  }
}
