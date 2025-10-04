import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added Firebase Auth import
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore import

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  final List<String> _availableInterests = [
    'Concerts',
    'Lectures',
    'Workshops',
    'Sports',
    'Art Exhibitions',
    'Theater',
    'Movies',
    'Outdoor Activities',
    'Food & Drink',
    'Meditation',
    'Yoga',
    'Master-classes',
  ];

  final List<String> _selectedInterests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
    });
    final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      final storedInterests = data?['interests'] as List<dynamic>?;
      if (storedInterests != null) {
        setState(() {
          _selectedInterests.clear();
          _selectedInterests.addAll(storedInterests.map((e) => e.toString()));
        });
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save preferences.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'interests': _selectedInterests,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preferences: $e')),
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
        title: const Text('Set Your Preferences'),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'What are your leisure interests?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _availableInterests.length,
                              itemBuilder: (context, index) {
                                final interest = _availableInterests[index];
                                return CheckboxListTile(
                                  title: Text(interest),
                                  value: _selectedInterests.contains(interest),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedInterests.add(interest);
                                      } else {
                                        _selectedInterests.remove(interest);
                                      }
                                    });
                                  },
                                  activeColor: Colors.deepPurple,
                                  checkColor: Colors.white,
                                );
                              },
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              onPressed: _savePreferences,
                              icon: const Icon(Icons.save, color: Colors.white),
                              label: const Text('Save Preferences', style: TextStyle(color: Colors.white)),
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

