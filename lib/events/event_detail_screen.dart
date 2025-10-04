import 'package:flutter/material.dart';
import 'package:leisure_app/chat/chat_screen.dart';
import 'package:leisure_app/chat/private_chat_screen.dart';
import 'package:leisure_app/events/review_screen.dart';
import 'package:leisure_app/profile/user_profile_view_screen.dart'; // Added UserProfileViewScreen import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'package:leisure_app/events/edit_event_screen.dart'; // Import EditEventScreen
import 'package:leisure_app/screens/ticket_purchase_screen.dart'; // Import TicketPurchaseScreen
import 'package:leisure_app/screens/my_tickets_screen.dart'; // Import MyTicketsScreen

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isAttending = false;
  bool _isFavorited = false;
  bool _isInterestedInCoAttending = false; // New state variable
  User? _currentUser;
  String? _organizerId; // To store the organizer ID

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _checkIfAttending();
      _checkIfFavorited();
      _checkIfInterestedInCoAttending(); // New check
    }
  }

  Future<void> _checkIfAttending() async {
    if (_currentUser == null) return;
    final doc = await _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('attendees')
        .doc(_currentUser!.uid)
        .get();
    setState(() {
      _isAttending = doc.exists;
    });
  }

  Future<void> _joinEvent() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to join an event.')),
      );
      return;
    }

    setState(() {
      _isAttending = !_isAttending;
    });

    if (_isAttending) {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('attendees')
          .doc(_currentUser!.uid)
          .set({
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Anonymous',
        'userPhotoUrl': _currentUser!.photoURL,
        'timestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have joined this event!')),
      );
    } else {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('attendees')
          .doc(_currentUser!.uid)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left this event.')),
      );
    }
  }

  Future<void> _checkIfFavorited() async {
    if (_currentUser == null) return;
    final doc = await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('favorites')
        .doc(widget.eventId)
        .get();
    setState(() {
      _isFavorited = doc.exists;
    });
  }

  Future<void> _toggleFavorite(String eventTitle) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to favorite an event.')),
      );
      return;
    }

    setState(() {
      _isFavorited = !_isFavorited;
    });

    if (_isFavorited) {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(widget.eventId)
          .set({
        'eventId': widget.eventId,
        'eventTitle': eventTitle,
        'timestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event added to favorites!')),
      );
    } else {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('favorites')
          .doc(widget.eventId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event removed from favorites.')),
      );
    }
  }

  Future<void> _checkIfInterestedInCoAttending() async {
    if (_currentUser == null) return;
    final doc = await _firestore
        .collection('events')
        .doc(widget.eventId)
        .collection('co_attending_interests')
        .doc(_currentUser!.uid)
        .get();
    setState(() {
      _isInterestedInCoAttending = doc.exists;
    });
  }

  Future<void> _toggleCoAttendingInterest(String eventTitle) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to express interest.')),
      );
      return;
    }

    setState(() {
      _isInterestedInCoAttending = !_isInterestedInCoAttending;
    });

    if (_isInterestedInCoAttending) {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('co_attending_interests')
          .doc(_currentUser!.uid)
          .set({
        'userId': _currentUser!.uid,
        'userName': _currentUser!.displayName ?? 'Anonymous',
        'userPhotoUrl': _currentUser!.photoURL,
        'timestamp': Timestamp.now(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are now interested in co-attending this event!')),
      );
    } else {
      await _firestore
          .collection('events')
          .doc(widget.eventId)
          .collection('co_attending_interests')
          .doc(_currentUser!.uid)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are no longer interested in co-attending this event.')),
      );
    }
  }

  void _shareEvent(String title, String description, String? imageUrl) {
    String shareText = 'Check out this event: $title!\n$description';
    if (imageUrl != null && imageUrl.isNotEmpty) {
      shareText += '\nImage: $imageUrl'; // Or provide a specific event URL if available
    }
    Share.share(shareText, subject: 'Event Recommendation');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading Event...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Event Not Found')),
            body: const Center(child: Text('Event not found.')),
          );
        }

        final eventData = snapshot.data!.data() as Map<String, dynamic>;
        _organizerId = eventData['organizerId']; // Set organizer ID
        final bool isOrganizer = _currentUser?.uid == _organizerId;

        final List<String> imageUrls = (eventData['imageUrls'] as List<dynamic>?)?.map((item) => item.toString()).toList() ?? [];
        final String title = eventData['title'] ?? 'No Title';
        final String description = eventData['description'] ?? 'No Description';
        final String location = eventData['location'] ?? 'No Location';
        final String date = eventData['date'] ?? 'No Date';
        final String time = eventData['time'] ?? 'No Time';
        final String price = eventData['price'] ?? 'Free';
        final String contactPerson = eventData['contactPerson'] ?? 'N/A';
        final String contactPhone = eventData['contactPhone'] ?? 'N/A';
        final String socialLink = eventData['socialLink'] ?? '';
        final int maxParticipants = int.tryParse(eventData['maxParticipants'] ?? '0') ?? 0;
        final List<dynamic> sessions = eventData['sessions'] ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
            actions: [
              if (isOrganizer)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditEventScreen(
                          eventId: widget.eventId,
                          eventData: eventData,
                        ),
                      ),
                    );
                  },
                ),
              if (_currentUser != null)
                IconButton(
                  icon: Icon(_isFavorited ? Icons.favorite : Icons.favorite_border),
                  color: _isFavorited ? Colors.red : Theme.of(context).appBarTheme.foregroundColor,
                  onPressed: () => _toggleFavorite(title),
                ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareEvent(title, description, imageUrls.isNotEmpty ? imageUrls[0] : null),
              ),
            ],
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
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrls.isNotEmpty)
                      Container(
                        height: 250,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(imageUrls[0]), // Display the first image
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: const TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow(Icons.location_on, location),
                          _buildInfoRow(Icons.calendar_today, date),
                          _buildInfoRow(Icons.access_time, time),
                          _buildInfoRow(Icons.attach_money, price),
                          _buildInfoRow(Icons.person_outline, contactPerson),
                          _buildInfoRow(Icons.phone, contactPhone),
                          if (socialLink.isNotEmpty)
                            _buildInfoRow(Icons.link, socialLink),
                          if (maxParticipants > 0)
                            _buildInfoRow(Icons.group, 'Max Participants: $maxParticipants'),
                          const SizedBox(height: 20),
                          if (sessions.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sessions:',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                ...sessions.map((session) => Text(
                                      '${session['date']} at ${session['time']}',
                                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                                    )),
                                const SizedBox(height: 20),
                              ],
                            ),
                          // Attendees Section
                          const Text(
                            'Attendees:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          _buildAttendeesList(widget.eventId),
                          const SizedBox(height: 20),
                          // Co-attending Interest Button
                          if (_currentUser != null)
                            ElevatedButton.icon(
                              onPressed: () => _toggleCoAttendingInterest(title),
                              icon: Icon(_isInterestedInCoAttending ? Icons.group_off : Icons.group_add, color: Colors.white),
                              label: Text(_isInterestedInCoAttending
                                  ? 'No Longer Interested in Co-attending'
                                  : 'Interested in Co-attending',
                                style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isInterestedInCoAttending ? Colors.orangeAccent : Colors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Co-attending Interests List
                          const Text(
                            'Interested in Co-attending:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          _buildCoAttendingInterestsList(widget.eventId),
                          const SizedBox(height: 20),
                          // Chat and Join Event Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (_currentUser == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('You need to be logged in to chat.')),
                                      );
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          eventId: widget.eventId,
                                          eventTitle: title,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chat, color: Colors.white),
                                  label: const Text('Chat with Attendees', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _joinEvent,
                                  icon: Icon(_isAttending ? Icons.event_busy : Icons.event_available, color: Colors.white),
                                  label: Text(_isAttending ? 'Leave Event' : 'Join Event', style: const TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isAttending ? Colors.redAccent : Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You need to be logged in to leave a review.')),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReviewScreen(
                                    eventId: widget.eventId,
                                    eventTitle: title,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.rate_review, color: Colors.white),
                            label: const Text('Leave a Review', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Ticket purchase buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TicketPurchaseScreen(
                                          eventId: widget.eventId,
                                          eventTitle: title,
                                          eventDate: date,
                                          eventTime: time,
                                          venueName: location,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                                  label: const Text('Купить билет', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MyTicketsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.confirmation_number, color: Colors.white),
                                  label: const Text('Мои билеты', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Reviews Section
                          const Text(
                            'Reviews:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 10),
                          _buildReviewsList(widget.eventId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesList(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('events').doc(eventId).collection('attendees').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No attendees yet.',
            style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
          );
        }

        final attendees = snapshot.data!.docs;
        final bool isOrganizer = _currentUser?.uid == _organizerId;

        return SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: attendees.length,
            itemBuilder: (context, index) {
              final attendee = attendees[index].data() as Map<String, dynamic>;
              final String attendeeId = attendee['userId'] ?? '';
              final String attendeeName = attendee['userName'] ?? 'Anonymous';
              final String? attendeePhotoUrl = attendee['userPhotoUrl'] as String?;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileViewScreen(
                        userId: attendeeId,
                        userName: attendeeName,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: attendeePhotoUrl != null && attendeePhotoUrl.isNotEmpty
                                ? NetworkImage(attendeePhotoUrl)
                                : null,
                            child: attendeePhotoUrl == null || attendeePhotoUrl.isEmpty
                                ? const Icon(Icons.person, size: 30, color: Colors.white)
                                : null,
                          ),
                          if (isOrganizer && attendeeId != _organizerId) // Allow organizer to remove others
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _confirmRemoveAttendee(eventId, attendeeId, attendeeName),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.red.shade400,
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        attendeeName,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveAttendee(String eventId, String attendeeId, String attendeeName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Attendee'),
        content: Text('Are you sure you want to remove $attendeeName from this event?\'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .doc(attendeeId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$attendeeName has been removed from the event.'),),
      );
    }
  }

  Widget _buildCoAttendingInterestsList(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .doc(eventId)
          .collection('co_attending_interests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No one is interested in co-attending this event yet.',
            style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
          );
        }

        final interests = snapshot.data!.docs;

        return SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: interests.length,
            itemBuilder: (context, index) {
              final interest = interests[index].data() as Map<String, dynamic>;
              final String userId = interest['userId'] ?? '';
              final String userName = interest['userName'] ?? 'Anonymous';
              final String? userPhotoURL = interest['userPhotoUrl'] as String?;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileViewScreen(
                        userId: userId,
                        userName: userName,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: userPhotoURL != null && userPhotoURL.isNotEmpty
                            ? NetworkImage(userPhotoURL)
                            : null,
                        child: userPhotoURL == null || userPhotoURL.isEmpty
                            ? const Icon(Icons.person, size: 30, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReviewsList(String eventId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .doc(eventId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No reviews yet.',
            style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
          );
        }

        final reviews = snapshot.data!.docs;
        double averageRating = 0;
        if (reviews.isNotEmpty) {
          averageRating = reviews.map((doc) => (doc.data() as Map<String, dynamic>)['rating'] as double) .reduce((a, b) => a + b) / reviews.length;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Rating: ${averageRating.toStringAsFixed(1)} / 5.0',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final reviewData = reviews[index].data() as Map<String, dynamic>;
                final String reviewerName = reviewData['reviewerName'] ?? 'Anonymous';
                final double rating = reviewData['rating'] ?? 0.0;
                final String reviewText = reviewData['reviewText'] ?? '';
                final String? reviewerPhotoUrl = reviewData['reviewerPhotoUrl'] as String?;
                final Timestamp timestamp = reviewData['timestamp'] as Timestamp;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: reviewerPhotoUrl != null && reviewerPhotoUrl.isNotEmpty
                                  ? NetworkImage(reviewerPhotoUrl)
                                  : null,
                              child: reviewerPhotoUrl == null || reviewerPhotoUrl.isEmpty
                                  ? const Icon(Icons.person, size: 24, color: Colors.deepPurple)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              reviewerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            const Spacer(),
                            Row(
                              children: List.generate(5, (starIndex) {
                                return Icon(
                                  starIndex < rating ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 18,
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reviewText,
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${timestamp.toDate().toLocal().toString().split(' ')[0]}', // Display only date
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

