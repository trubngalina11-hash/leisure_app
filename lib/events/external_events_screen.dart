import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisure_app/services/event_scraping_service.dart';
import 'package:leisure_app/services/event_sync_service.dart';
import 'package:leisure_app/events/event_detail_screen.dart';
import 'package:leisure_app/widgets/modern_event_card.dart';
import 'package:intl/intl.dart';

class ExternalEventsScreen extends StatefulWidget {
  const ExternalEventsScreen({super.key});

  @override
  State<ExternalEventsScreen> createState() => _ExternalEventsScreenState();
}

class _ExternalEventsScreenState extends State<ExternalEventsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<EventData> _externalEvents = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _selectedSource = 'All';
  final List<String> _sources = ['All', ...EventScrapingService.availableSources];
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadExternalEvents();
    _loadSyncStatus();
  }

  Future<void> _loadExternalEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await EventScrapingService.scrapeAllSources(limitPerSource: 15);
      setState(() {
        _externalEvents = events;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки событий: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      final status = await EventSyncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
      });
    } catch (e) {
      print('Error loading sync status: $e');
    }
  }

  Future<void> _syncExternalEvents() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await EventSyncService.syncExternalEvents(limitPerSource: 15);
      await _loadSyncStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Синхронизация завершена успешно'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка синхронизации: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _addEventToFirestore(EventData event) async {
    try {
      await _firestore.collection('events').add({
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'date': event.date,
        'time': event.time,
        'price': event.price,
        'imageUrls': event.imageUrl.isNotEmpty ? [event.imageUrl] : [],
        'category': event.category,
        'source': event.source,
        'sourceUrl': event.sourceUrl,
        'timestamp': Timestamp.now(),
        'organizerId': 'external_source',
        'organizerName': event.source,
        'participants': [],
        'maxParticipants': 100,
        'isExternal': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Событие "${event.title}" добавлено в приложение'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка добавления события: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<EventData> get _filteredEvents {
    if (_selectedSource == 'All') {
      return _externalEvents;
    }
    return _externalEvents.where((event) => event.source == _selectedSource).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Внешние события'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncExternalEvents,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExternalEvents,
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
              // Статус синхронизации
              if (_syncStatus != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sync,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Последняя синхронизация:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _syncStatus!['lastSync'] != null
                                      ? DateFormat('dd.MM.yyyy HH:mm').format(
                                          (_syncStatus!['lastSync'] as Timestamp).toDate(),
                                        )
                                      : 'Никогда',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Событий: ${_syncStatus!['eventsCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Добавлено: ${_syncStatus!['addedCount'] ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Фильтр по источникам
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Источники событий:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: _sources.map((source) {
                            final isSelected = _selectedSource == source;
                            return FilterChip(
                              label: Text(source),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedSource = source;
                                });
                              },
                              selectedColor: Colors.deepPurple.shade200,
                              checkmarkColor: Colors.deepPurple.shade700,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Список событий
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredEvents.isEmpty
                        ? const Center(
                            child: Text(
                              'События не найдены',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredEvents.length,
                            itemBuilder: (context, index) {
                              final event = _filteredEvents[index];
                              return ModernEventCard(
                                title: event.title,
                                location: event.location,
                                date: event.date,
                                time: event.time,
                                imageUrl: event.imageUrl.isNotEmpty ? event.imageUrl : null,
                                price: event.price,
                                category: event.category,
                                source: event.source,
                                onTap: () {
                                  _showEventDetails(event);
                                },
                                onFavorite: () {
                                  _addEventToFirestore(event);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEventDetails(EventData event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            event.imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.image, size: 60),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.source,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(Icons.location_on, 'Место', event.location),
                      _buildDetailRow(Icons.calendar_today, 'Дата', event.date),
                      _buildDetailRow(Icons.access_time, 'Время', event.time),
                      _buildDetailRow(Icons.attach_money, 'Цена', event.price),
                      _buildDetailRow(Icons.category, 'Категория', event.category),
                      const SizedBox(height: 20),
                      const Text(
                        'Описание:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        event.description,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _addEventToFirestore(event);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить в приложение'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (event.sourceUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Можно добавить открытие ссылки в браузере
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Открыть на сайте'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
