import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leisure_app/events/event_detail_screen.dart';
import 'package:leisure_app/events/create_event_screen.dart';
import 'package:leisure_app/events/external_events_screen.dart';
import 'package:leisure_app/preferences/preference_screen.dart';
import 'package:leisure_app/widgets/modern_event_card.dart';
import 'package:intl/intl.dart'; // Added for date formatting

// Simple in-memory cache for event categories
class EventCategoryCache {
  static final List<String> _categories = [
    'Concert',
    'Lecture',
    'Workshop',
    'Sports',
    'Art Exhibition',
    'Theater',
    'Movie',
    'Outdoor Activity',
    'Food & Drink',
    'Meditation',
    'Yoga',
    'Master-class',
  ];

  static List<String> get categories => _categories;
}

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> _events = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _eventsPerPage = 10;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;

  List<String> _userInterests = [];
  final List<String> _eventCategories = EventCategoryCache.categories; // Use cached categories

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadUserPreferences();
    _loadInitialEvents();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterEvents();
  }

  Future<void> _loadUserPreferences() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!['interests'] != null) {
        setState(() {
          _userInterests = List<String>.from(doc.data()!['interests']);
        });
      }
    }
  }

  Future<void> _loadInitialEvents() async {
    setState(() {
      _isLoadingMore = true;
    });
    Query query = _firestore.collection('events').orderBy('timestamp', descending: true).limit(_eventsPerPage);
    final snap = await query.get();
    setState(() {
      _events = snap.docs;
      _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == _eventsPerPage;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadMoreEvents() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    Query query = _firestore.collection('events').orderBy('timestamp', descending: true).startAfterDocument(_lastDocument!).limit(_eventsPerPage);
    final snap = await query.get();

    setState(() {
      _events.addAll(snap.docs);
      _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : _lastDocument;
      _hasMore = snap.docs.length == _eventsPerPage;
      _isLoadingMore = false;
    });
  }

  Future<void> _filterEvents() async {
    setState(() {
      _isLoadingMore = true;
      _events = []; // Clear current events for new filter
      _lastDocument = null;
      _hasMore = true;
    });

    Query query = _firestore.collection('events').orderBy('timestamp', descending: true);

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    // Filter by date range
    if (_startDate != null) {
      String startDateFormatted = DateFormat('dd.MM.yyyy').format(_startDate!)
          .split('.')
          .reversed
          .join('-'); // YYYY-MM-DD for comparison
      query = query.where('date', isGreaterThanOrEqualTo: startDateFormatted);
    }
    if (_endDate != null) {
      String endDateFormatted = DateFormat('dd.MM.yyyy').format(_endDate!)
          .split('.')
          .reversed
          .join('-'); // YYYY-MM-DD for comparison
      query = query.where('date', isLessThanOrEqualTo: endDateFormatted);
    }

    // Filter by title/description (client-side for now, as full-text search is complex with Firestore)
    final snap = await query.get();
    List<DocumentSnapshot> filteredDocs = snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String title = data['title']?.toLowerCase() ?? '';
      final String description = data['description']?.toLowerCase() ?? '';
      final String searchTerm = _searchController.text.toLowerCase().trim();
      final String category = data['category']?.toLowerCase() ?? '';

      bool matchesSearch = searchTerm.isEmpty || title.contains(searchTerm) || description.contains(searchTerm);

      bool matchesPreferences = _userInterests.isEmpty || _userInterests.map((e) => e.toLowerCase()).contains(category);

      return matchesSearch && matchesPreferences;
    }).toList();

    setState(() {
      _events = filteredDocs;
      _lastDocument = filteredDocs.isNotEmpty ? filteredDocs.last : null;
      _hasMore = false; // All filtered events are loaded at once
      _isLoadingMore = false;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _filterEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExternalEventsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateEventScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PreferenceScreen()),
              );
            },
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
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search events',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Icon(Icons.category),
                          ),
                          items: _eventCategories
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCategory = newValue;
                            });
                            _filterEvents();
                          },
                          hint: const Text('Select Category'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                onTap: () => _selectDate(context, true),
                                decoration: InputDecoration(
                                  labelText: _startDate == null
                                      ? 'Start Date'
                                      : DateFormat('dd.MM.yyyy').format(_startDate!),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                onTap: () => _selectDate(context, false),
                                decoration: InputDecoration(
                                  labelText: _endDate == null
                                      ? 'End Date'
                                      : DateFormat('dd.MM.yyyy').format(_endDate!),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!_isLoadingMore &&
                        scrollInfo.metrics.pixels ==
                            scrollInfo.metrics.maxScrollExtent &&
                        _hasMore) {
                      _loadMoreEvents();
                      return true;
                    }
                    return false;
                  },
                  child: ListView.builder(
                    itemCount: _events.length + (_hasMore ? 1 : 0), // Add 1 for loading indicator
                    itemBuilder: (context, index) {
                      if (index == _events.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final event = _events[index].data() as Map<String, dynamic>;
                      final String eventId = _events[index].id;
                      final List<String> imageUrls = (event['imageUrls'] as List<dynamic>?)?.map((item) => item.toString()).toList() ?? [];

                      return ModernEventCard(
                        title: event['title'] ?? 'Без названия',
                        location: event['location'] ?? 'Место не указано',
                        date: event['date'] ?? 'Дата не указана',
                        time: event['time'] ?? 'Время не указано',
                        imageUrl: imageUrls.isNotEmpty ? imageUrls[0] : null,
                        price: event['price'],
                        category: event['category'],
                        source: event['source'],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailScreen(eventId: eventId),
                            ),
                          );
                        },
                        onFavorite: () {
                          // TODO: Implement favorite functionality
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

