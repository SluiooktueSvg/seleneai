
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });
}
