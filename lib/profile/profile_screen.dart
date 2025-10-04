import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  User? _currentUser;
  String? _displayName;
  String? _photoURL;
  File? _pickedImage; // To hold the image picked from gallery
  bool _isLoading = false;
  bool _receiveFavoriteEventNotifications = false;
  bool _receiveOrganizerNotifications = false;

  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
    });
    final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      _displayName = data?['displayName'] as String?;
      _photoURL = data?['photoURL'] as String?;
      _displayNameController.text = _displayName ?? '';
      _receiveFavoriteEventNotifications = data?['receiveFavoriteEventNotifications'] as bool? ?? false;
      _receiveOrganizerNotifications = data?['receiveOrganizerNotifications'] as bool? ?? false;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedImage == null || _currentUser == null) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_images')
          .child('${_currentUser!.uid}.jpg');
      await storageRef.putFile(_pickedImage!);
      final url = await storageRef.getDownloadURL();

      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'photoURL': url,
      });
      await _currentUser!.updatePhotoURL(url); // Update Firebase Auth profile
      setState(() {
        _photoURL = url;
        _pickedImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });
    try {
      final newDisplayName = _displayNameController.text.trim();
      if (newDisplayName != _displayName) {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'displayName': newDisplayName,
        });
        await _currentUser!.updateDisplayName(newDisplayName); // Update Firebase Auth profile
        setState(() {
          _displayName = newDisplayName;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateNotificationPreferences() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'receiveFavoriteEventNotifications': _receiveFavoriteEventNotifications,
        'receiveOrganizerNotifications': _receiveOrganizerNotifications,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notification preferences: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
                            GestureDetector(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.deepPurple.shade300,
                                backgroundImage: _pickedImage != null
                                    ? FileImage(_pickedImage!)
                                    : (_photoURL != null && _photoURL!.isNotEmpty
                                        ? NetworkImage(_photoURL!)
                                        : null) as ImageProvider?,
                                child: (_pickedImage == null && (_photoURL == null || _photoURL!.isEmpty))
                                    ? Text(
                                        _displayName?.isNotEmpty == true ? _displayName![0].toUpperCase() : '',
                                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                              label: const Text('Change Photo', style: TextStyle(color: Colors.deepPurple)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                            if (_pickedImage != null)
                              ElevatedButton.icon(
                                onPressed: _uploadImage,
                                icon: const Icon(Icons.upload_file, color: Colors.white),
                                label: const Text('Upload Profile Photo', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                              ),
                            const SizedBox(height: 20),
                            // Notification Settings Section
                            Text(
                              'Notification Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SwitchListTile(
                              title: const Text('Favorite Event Updates', style: TextStyle(color: Colors.white70)),
                              value: _receiveFavoriteEventNotifications,
                              onChanged: (bool value) {
                                setState(() {
                                  _receiveFavoriteEventNotifications = value;
                                });
                                _updateNotificationPreferences();
                              },
                              activeColor: Colors.deepPurple,
                              inactiveTrackColor: Colors.grey.shade700,
                              tileColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              title: const Text('Organizer Updates', style: TextStyle(color: Colors.white70)),
                              value: _receiveOrganizerNotifications,
                              onChanged: (bool value) {
                                setState(() {
                                  _receiveOrganizerNotifications = value;
                                });
                                _updateNotificationPreferences();
                              },
                              activeColor: Colors.deepPurple,
                              inactiveTrackColor: Colors.grey.shade700,
                              tileColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }
}
