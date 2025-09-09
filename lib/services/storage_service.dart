import 'dart:convert';
import 'package:selene/models/conversation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _conversationsKeyPrefix = 'conversations_';

  String _getUserConversationsKey(String userId) {
    return '$_conversationsKeyPrefix$userId';
  }

  Future<void> saveConversation(String userId, Conversation conversation) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await loadConversations(userId);
    final index = conversations.indexWhere((c) => c.id == conversation.id);

    if (index != -1) {
      conversations[index] = conversation;
    } else {
      conversations.add(conversation);
    }

    final conversationsJson = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_getUserConversationsKey(userId), conversationsJson);
  }

  Future<List<Conversation>> loadConversations(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final conversationsJson = prefs.getStringList(_getUserConversationsKey(userId)) ?? [];
    return conversationsJson
        .map((json) => Conversation.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final conversations = await loadConversations(userId);
    conversations.removeWhere((c) => c.id == conversationId);
    final conversationsJson = conversations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_getUserConversationsKey(userId), conversationsJson);
  }

  Future<void> clearConversations(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getUserConversationsKey(userId));
  }
}
