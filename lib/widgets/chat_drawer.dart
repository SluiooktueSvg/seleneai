import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:selene/models/conversation.dart';
import 'package:selene/models/chat_message.dart'; // Importamos ChatMessage
import 'package:selene/services/firestore_service.dart'; // Importamos FirestoreService

class ChatDrawer extends StatefulWidget {
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
  _ChatDrawerState createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(); // Agregamos un FocusNode
  bool _isSearching = false;
  List<ChatMessage> _searchResults = []; // Lista para almacenar los resultados de la búsqueda
  final FirestoreService _firestoreService = FirestoreService(); // Instancia de FirestoreService

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged); // Agregamos un listener al FocusNode
  }

  void _onSearchChanged() async {
    final query = _searchController.text.toLowerCase(); // Convertir a minúsculas para búsqueda insensible
    setState(() {
      // Verificamos si la consulta no está vacía O si el TextField tiene el foco
      _isSearching = query.isNotEmpty || _searchFocusNode.hasFocus;
    });

    if (_isSearching && query.isNotEmpty) {
      final results = await _firestoreService.searchMessages(query, widget.user!.uid);
      setState(() {
        _searchResults = results;
      });
    } else {
      setState(() {
        _searchResults = []; // Limpiar resultados si la búsqueda está vacía
      });
    }
  }

  // Nuevo método para manejar cambios de foco
  void _onFocusChanged() {
     setState(() {
        _isSearching = _searchController.text.isNotEmpty || _searchFocusNode.hasFocus;
      });
  }


  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Importante liberar el FocusNode
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isSearching ? MediaQuery.of(context).size.width : 304.0,
      child: Drawer(
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
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode, // Asociamos el FocusNode al TextField
                          onTap: () {
                            // No necesitamos setState aquí ya que el listener del FocusNode lo manejará
                          },
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search, color: Colors.white54),
                            hintText: 'Buscar',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: _isSearching ? 20.0 : null),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: _isSearching
                          ? const Icon(Icons.close, color: Colors.white)
                          : const Icon(Icons.edit_outlined, color: Colors.white),
                      onPressed: () {
                        if (_isSearching) {
                          _searchController.clear();
                          _searchFocusNode.unfocus(); // Quitar el foco al cerrar
                           setState(() {
                              _isSearching = false;
                              _searchResults = []; // Limpiar resultados al cerrar
                            });
                           // Cerrar el drawer si estaba expandido y ya no hay búsqueda
                           if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                           }
                        } else {
                          widget.onNewChat();
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (_isSearching)
                Expanded(
                  child: _searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron resultados.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final message = _searchResults[index];
                            // Aquí puedes diseñar cómo mostrar cada resultado del mensaje
                            return ListTile(
                              title: Text(
                                message.text, // O el campo que contenga el texto del mensaje
                                style: const TextStyle(color: Colors.white),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Puedes añadir onTap para navegar a la conversación del mensaje
                            );
                          },
                        ),
                )
              else
                Expanded( // Envuelve la columna de opciones y la lista de conversaciones en un Expanded
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: Colors.white),
                        title: const Text('Nuevo chat', style: TextStyle(color: Colors.white)),
                        onTap: widget.onNewChat,
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
                        title: const Text('Proyectos', style: TextStyle(color: Colors.white)),
                        onTap: () { /* No action yet */ },
                      ),
                      const Divider(color: Colors.white24), // Agrega un divisor entre opciones y conversaciones
                       Expanded( // Envuelve la lista de conversaciones en un Expanded
                        child: widget.conversations.isEmpty
                            ? const Center(
                                child: Text(
                                  'Aquí se mostrará tu historial de chats.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                itemCount: widget.conversations.length,
                                itemBuilder: (context, index) {
                                  final conversation = widget.conversations[index];
                                  return ListTile(
                                    leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                                    title: Text(
                                      conversation.title,
                                      style: const TextStyle(color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => widget.onLoadConversation(conversation),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: widget.user?.photoURL != null
                      ? NetworkImage(widget.user!.photoURL!)
                      : null,
                  child: widget.user?.photoURL == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(widget.user?.displayName ?? 'Usuario', style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: widget.onSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
