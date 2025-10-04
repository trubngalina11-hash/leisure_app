import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisure_app/chat/private_chat_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserProfileViewScreen({super.key, required this.userId, required this.userName});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _userData; // To store fetched user data
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userDisplayName = _userData?['displayName'] as String? ?? widget.userName;
    final String? userEmail = _userData?['email'] as String?;
    final String? userPhotoURL = _userData?['photoURL'] as String?;
    final List<dynamic>? userInterests = _userData?['interests'] as List<dynamic>?;

    final bool isCurrentUser = _currentUser != null && _currentUser!.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(userDisplayName ?? 'User Profile'),
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
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.deepPurple.shade300,
                              backgroundImage: userPhotoURL != null && userPhotoURL.isNotEmpty
                                  ? NetworkImage(userPhotoURL)
                                  : null,
                              child: userPhotoURL == null || userPhotoURL.isEmpty
                                  ? Text(
                                      (userDisplayName ?? '').isNotEmpty ? (userDisplayName ?? '')[0].toUpperCase() : '',
                                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              userDisplayName ?? 'Unknown User',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            if (userEmail != null)
                              Text(
                                'Email: $userEmail',
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            const SizedBox(height: 20),
                            if (userInterests != null && userInterests.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Interests:',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8.0,
                                    runSpacing: 4.0,
                                    children: userInterests
                                        .map((interest) => Chip(
                                              label: Text(interest),
                                              backgroundColor: Colors.lightBlueAccent.shade100,
                                              labelStyle: TextStyle(color: Colors.deepPurple.shade700),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 30),
                            if (!isCurrentUser)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PrivateChatScreen(
                                        receiverId: widget.userId,
                                        receiverName: userDisplayName ?? 'Unknown User',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.message, color: Colors.white),
                                label: const Text('Message', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
