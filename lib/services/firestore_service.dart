import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:selene/models/conversation.dart';
import 'package:selene/models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveConversation(String userId, Conversation conversation) async {
    final userDocRef = _db.collection('users').doc(userId);
    final conversationDocRef = userDocRef.collection('conversations').doc(conversation.id);

    // Convert messages to a list of maps for Firestore
    final messagesData = conversation.messages.map((message) => message.toJson()).toList();

    await conversationDocRef.set({
      'id': conversation.id,
      'title': conversation.title,
      'messages': messagesData,
      'timestamp': conversation.messages.isNotEmpty ? Timestamp.fromDate(conversation.messages.first.timestamp) : FieldValue.serverTimestamp(), // Use the timestamp of the first message or server timestamp
    });
  }

  Future<List<Conversation>> loadConversations(String userId) async {
    final userDocRef = _db.collection('users').doc(userId);
    final conversationsCollection = userDocRef.collection('conversations');

    final querySnapshot = await conversationsCollection.orderBy('timestamp', descending: true).get();

    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      final messagesData = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      final messages = messagesData.map((msgData) {
        // Ensure timestamp is converted from Firestore Timestamp to DateTime
        return ChatMessage.fromJson(msgData);
      }).toList();

      return Conversation(
        id: data['id'],
        title: data['title'],
        messages: messages,
      );
    }).toList();
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    final userDocRef = _db.collection('users').doc(userId);
    final conversationDocRef = userDocRef.collection('conversations').doc(conversationId);
    await conversationDocRef.delete();
  }

  Future<void> clearUserConversations(String userId) async {
    final userDocRef = _db.collection('users').doc(userId);
    final conversationsCollection = userDocRef.collection('conversations');

    final querySnapshot = await conversationsCollection.get();
    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Nuevo método para buscar mensajes en las conversaciones del usuario
  Future<List<ChatMessage>> searchMessages(String query, String userId) async {
    final userDocRef = _db.collection('users').doc(userId);
    final conversationsCollection = userDocRef.collection('conversations');

    final querySnapshot = await conversationsCollection.get();
    List<ChatMessage> searchResults = [];

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final messagesData = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      final messages = messagesData.map((msgData) {
        return ChatMessage.fromJson(msgData);
      }).toList();

      // Filtrar mensajes que contengan la palabra clave (insensible a mayúsculas/minúsculas)
      final matchingMessages = messages.where((message) => message.text.toLowerCase().contains(query)).toList();
      searchResults.addAll(matchingMessages);
    }

    return searchResults;
  }
}
