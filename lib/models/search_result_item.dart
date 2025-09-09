// lib/models/search_result_item.dart
import 'package:selene/models/chat_message.dart';

class SearchResultItem {
  final ChatMessage message;
  final String conversationTitle;

  SearchResultItem({
    required this.message,
    required this.conversationTitle,
  });
}
