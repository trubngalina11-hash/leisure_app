import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisure_app/services/event_scraping_service.dart';

class EventSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Автоматическая синхронизация событий из внешних источников
  static Future<void> syncExternalEvents({int limitPerSource = 10}) async {
    try {
      print('Starting external events sync...');
      
      // Получаем события из всех источников
      final externalEvents = await EventScrapingService.scrapeAllSources(
        limitPerSource: limitPerSource,
      );
      
      print('Found ${externalEvents.length} external events');
      
      // Получаем существующие события из Firestore
      final existingEventsQuery = await _firestore
          .collection('events')
          .where('isExternal', isEqualTo: true)
          .get();
      
      final existingEvents = existingEventsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'],
          'source': data['source'],
          'sourceUrl': data['sourceUrl'],
        };
      }).toList();
      
      print('Found ${existingEvents.length} existing external events');
      
      // Добавляем новые события
      int addedCount = 0;
      for (final event in externalEvents) {
        // Проверяем, не существует ли уже такое событие
        final exists = existingEvents.any((existing) =>
            existing['title'] == event.title &&
            existing['source'] == event.source);
        
        if (!exists) {
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
            'lastSynced': Timestamp.now(),
          });
          addedCount++;
        }
      }
      
      print('Added $addedCount new external events');
      
      // Обновляем время последней синхронизации
      await _firestore.collection('sync_status').doc('external_events').set({
        'lastSync': Timestamp.now(),
        'eventsCount': externalEvents.length,
        'addedCount': addedCount,
      });
      
    } catch (e) {
      print('Error syncing external events: $e');
      rethrow;
    }
  }
  
  // Получение статистики синхронизации
  static Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final doc = await _firestore.collection('sync_status').doc('external_events').get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print('Error getting sync status: $e');
    }
    return null;
  }
  
  // Очистка старых внешних событий
  static Future<void> cleanupOldExternalEvents({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final oldEventsQuery = await _firestore
          .collection('events')
          .where('isExternal', isEqualTo: true)
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldEventsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('Cleaned up ${oldEventsQuery.docs.length} old external events');
      
    } catch (e) {
      print('Error cleaning up old external events: $e');
    }
  }
  
  // Получение событий по источнику
  static Future<List<DocumentSnapshot>> getEventsBySource(String source) async {
    try {
      final query = await _firestore
          .collection('events')
          .where('isExternal', isEqualTo: true)
          .where('source', isEqualTo: source)
          .orderBy('timestamp', descending: true)
          .get();
      
      return query.docs;
    } catch (e) {
      print('Error getting events by source: $e');
      return [];
    }
  }
  
  // Получение всех внешних событий
  static Future<List<DocumentSnapshot>> getAllExternalEvents() async {
    try {
      final query = await _firestore
          .collection('events')
          .where('isExternal', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();
      
      return query.docs;
    } catch (e) {
      print('Error getting all external events: $e');
      return [];
    }
  }
  
  // Удаление внешнего события
  static Future<void> removeExternalEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
      print('Removed external event: $eventId');
    } catch (e) {
      print('Error removing external event: $e');
      rethrow;
    }
  }
  
  // Обновление внешнего события
  static Future<void> updateExternalEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('events').doc(eventId).update({
        ...updates,
        'lastUpdated': Timestamp.now(),
      });
      print('Updated external event: $eventId');
    } catch (e) {
      print('Error updating external event: $e');
      rethrow;
    }
  }
}
