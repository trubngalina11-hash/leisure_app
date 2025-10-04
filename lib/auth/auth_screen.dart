import 'package:flutter/material.dart';
import 'package:leisure_app/auth/login_screen.dart';
import 'package:leisure_app/auth/registration_screen.dart';
import 'package:leisure_app/events/create_event_screen.dart';
import 'package:leisure_app/events/event_list_screen.dart';
import 'package:leisure_app/preferences/preference_screen.dart';
import 'package:leisure_app/profile/profile_screen.dart'; // Added ProfileScreen import
import 'package:leisure_app/favorites/favorites_screen.dart'; // Added FavoritesScreen import
import 'package:leisure_app/events/external_events_screen.dart'; // Added ExternalEventsScreen import
import 'package:leisure_app/screens/main_screen.dart'; // Added MainScreen import
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes to redirect if already logged in
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leisure App'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Stack(
        children: [
          // Background content or banner
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
            child: SingleChildScrollView(
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
                      Text(
                        'Welcome to Leisure App!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()));
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Register'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.lightBlueAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 30),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PreferenceScreen()));
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Set Preferences'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added padding
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateEventScreen()));
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Create Event'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added padding
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const EventListScreen()));
                        },
                        icon: const Icon(Icons.list),
                        label: const Text('View Events'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added padding
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Added Profile Button
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('View Profile'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added padding
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Added Favorite Events Button
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
                        },
                        icon: const Icon(Icons.favorite),
                        label: const Text('Favorite Events'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Added External Events Button
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ExternalEventsScreen()));
                        },
                        icon: const Icon(Icons.public),
                        label: const Text('External Events'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Logout button (for testing purposes)
                      TextButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logged out successfully!')),
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added padding
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
