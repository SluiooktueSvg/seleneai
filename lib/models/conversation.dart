import 'chat_message.dart';

class Conversation {
  final String id;
  String title;
  final String userName; // Campo añadido para el nombre de usuario
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.userName, // Requerido en el constructor
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'userName': userName, // Campo añadido a la serialización
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'],
        // Lee 'userName' del JSON, o usa 'Usuario' como valor por defecto.
        userName: json['userName'] ?? 'Usuario', 
        // Forma segura de decodificar la lista de mensajes
        messages: List<ChatMessage>.from(
            json['messages']?.map((x) => ChatMessage.fromJson(x)) ?? []),
      );
}
