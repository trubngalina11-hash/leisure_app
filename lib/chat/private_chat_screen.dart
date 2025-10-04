import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PrivateChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const PrivateChatScreen({super.key, required this.receiverId, required this.receiverName});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _chatRoomId;

  @override
  void initState() {
    super.initState();
    _createChatRoomId();
  }

  void _createChatRoomId() {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Create a unique chat room ID based on sorted user UIDs
    List<String> userIds = [currentUser.uid, widget.receiverId];
    userIds.sort(); // Ensure consistent order
    _chatRoomId = userIds.join('_');
  }

  void _sendMessage() async {
    final User? user = _auth.currentUser;
    if (user == null || _messageController.text.trim().isEmpty || _chatRoomId == null) {
      return;
    }

    await _firestore
        .collection('private_chats')
        .doc(_chatRoomId)
        .collection('messages')
        .add({
      'text': _messageController.text.trim(),
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Anonymous',
      'timestamp': Timestamp.now(),
    });
    _messageController.clear();
  }

  Future<void> _editMessage(String messageId, String currentText) async {
    final TextEditingController editController = TextEditingController(text: currentText);
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Message'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(hintText: 'Enter new message'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (editController.text.trim().isNotEmpty && _chatRoomId != null) {
                  await _firestore
                      .collection('private_chats')
                      .doc(_chatRoomId!)
                      .collection('messages')
                      .doc(messageId)
                      .update({'text': editController.text.trim(), 'edited': true});
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_chatRoomId != null) {
                  await _firestore
                      .collection('private_chats')
                      .doc(_chatRoomId!)
                      .collection('messages')
                      .doc(messageId)
                      .delete();
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.receiverName}'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Stack(
        children: [
          // Background gradient
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
            children: <Widget>[
              Expanded(
                child: _chatRoomId == null
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('private_chats')
                            .doc(_chatRoomId!)
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }
                          final messages = snapshot.data!.docs;
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(8.0),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final messageText = message['text'];
                              final messageSender = message['senderName'];
                              final messageSenderId = message['senderId'];
                              final isMe = currentUser != null && messageSenderId == currentUser.uid;

                              return GestureDetector(
                                onLongPress: () {
                                  if (isMe) {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) {
                                        return SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              ListTile(
                                                leading: const Icon(Icons.edit),
                                                title: const Text('Edit'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _editMessage(message.id, messageText);
                                                },
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.delete),
                                                title: const Text('Delete'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  _deleteMessage(message.id);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe) ...[
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.deepPurple.shade300,
                                        child: Text(
                                          messageSender.isNotEmpty ? messageSender[0].toUpperCase() : '',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Card(
                                      elevation: 4,
                                      color: isMe ? Colors.deepPurple.shade200 : Colors.lightBlueAccent.shade200,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              messageSender,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isMe ? Colors.deepPurple.shade800 : Colors.blue.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              messageText,
                                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                                            ),
                                            if ((message.data() as Map<String, dynamic>)['edited'] == true)
                                              const Text(
                                                '(Edited)',
                                                style: TextStyle(fontSize: 10, color: Colors.black54),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('HH:mm').format((message['timestamp'] as Timestamp).toDate()),
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blue.shade300,
                                        child: Text(
                                          messageSender.isNotEmpty ? messageSender[0].toUpperCase() : '',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
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
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Enter your message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
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
                      mini: true,
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.send),
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
