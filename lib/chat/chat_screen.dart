import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:leisure_app/profile/user_profile_view_screen.dart'; // Added UserProfileViewScreen import

class ChatScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const ChatScreen({super.key, required this.eventId, required this.eventTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<DocumentSnapshot> _messages = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _messagesPerPage = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.minScrollExtent &&
        _hasMore &&
        !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoadingMore = true;
    });
    Query query = _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .limit(_messagesPerPage);

    final snap = await query.get();
    setState(() {
      _messages = snap.docs;
      _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == _messagesPerPage;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMore || _isLoadingMore || _lastDocument == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    Query query = _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(_messagesPerPage);

    final snap = await query.get();

    setState(() {
      _messages.addAll(snap.docs);
      _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : _lastDocument;
      _hasMore = snap.docs.length == _messagesPerPage;
      _isLoadingMore = false;
    });
  }

  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    if (user == null || _messageController.text.trim().isEmpty) {
      return;
    }

    await _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('chats')
        .add({
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Anonymous',
      'senderPhotoUrl': user.photoURL,
      'message': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
    });
    _messageController.clear();
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showEditDeleteModal(String messageId, String currentMessage) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(messageId, currentMessage);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editMessage(String messageId, String currentMessage) async {
    String? newMessage = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: TextEditingController(text: currentMessage),
          decoration: const InputDecoration(hintText: 'Enter new message'),
          onChanged: (value) {
            currentMessage = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, currentMessage),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newMessage != null && newMessage.trim().isNotEmpty) {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('chats')
          .doc(messageId)
          .update({
        'message': newMessage.trim(),
        'timestamp': Timestamp.now(), // Update timestamp on edit
      });
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('chats')
          .doc(messageId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.eventTitle}'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.lightBlueAccent.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('events')
                      .doc(widget.eventId)
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .limit(_messages.length + (_hasMore ? _messagesPerPage : 0)) // Dynamically adjust limit
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }

                    _messages = snapshot.data!.docs; // Update messages from stream
                    // Note: _hasMore and _lastDocument are managed by _loadInitialMessages and _loadMoreMessages
                    // This StreamBuilder mostly rebuilds when new messages arrive or existing ones are updated/deleted.
                    // For loading more older messages, _loadMoreMessages will handle adding to _messages list.

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Show latest messages at the bottom
                      itemCount: _messages.length + (_isLoadingMore ? 1 : 0), // Add 1 for loading indicator at top
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final messageDoc = _messages[index];
                        final messageData = messageDoc.data() as Map<String, dynamic>;
                        final String senderId = messageData['senderId'] ?? '';
                        final String senderName = messageData['senderName'] ?? 'Anonymous';
                        final String? senderPhotoUrl = messageData['senderPhotoUrl'] as String?;
                        final String messageText = messageData['message'] ?? '';
                        final Timestamp timestamp = messageData['timestamp'] as Timestamp;

                        final bool isMe = senderId == user?.uid;

                        return GestureDetector(
                          onLongPress: () {
                            if (isMe) {
                              _showEditDeleteModal(messageDoc.id, messageText);
                            } else {
                              // Option to view profile of other user
                              showModalBottomSheet(
                                context: context,
                                builder: (context) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.person),
                                          title: const Text('View Profile'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => UserProfileViewScreen(
                                                  userId: senderId,
                                                  userName: senderName,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10.0),
                              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.deepPurple.shade300 : Colors.blueGrey.shade700,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(15),
                                  topRight: const Radius.circular(15),
                                  bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(0),
                                  bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe && senderPhotoUrl != null && senderPhotoUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileViewScreen(
                                              userId: senderId,
                                              userName: senderName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundImage: NetworkImage(senderPhotoUrl),
                                      ),
                                    ),
                                  if (!isMe && (senderPhotoUrl == null || senderPhotoUrl.isEmpty))
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileViewScreen(
                                              userId: senderId,
                                              userName: senderName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: Colors.grey.shade400,
                                        child: const Icon(Icons.person, size: 18, color: Colors.white),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMe ? 'You' : senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isMe ? Colors.white : Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          messageText,
                                          style: const TextStyle(color: Colors.white, fontSize: 15),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${timestamp.toDate().toLocal().hour}:${timestamp.toDate().toLocal().minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMe && senderPhotoUrl != null && senderPhotoUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileViewScreen(
                                              userId: senderId,
                                              userName: senderName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundImage: NetworkImage(senderPhotoUrl),
                                      ),
                                    ),
                                  if (isMe && (senderPhotoUrl == null || senderPhotoUrl.isEmpty))
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileViewScreen(
                                              userId: senderId,
                                              userName: senderName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: Colors.grey.shade400,
                                        child: const Icon(Icons.person, size: 18, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Send a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white70,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                      onPressed: _sendMessage,
                      backgroundColor: Colors.deepPurple,
                      mini: true,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
