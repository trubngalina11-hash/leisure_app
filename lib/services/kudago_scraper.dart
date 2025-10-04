import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import 'dart:convert';

// Модель для события
class EventData {
  final String title;
  final String description;
  final String location;
  final String date;
  final String time;
  final String price;
  final String imageUrl;
  final String source;
  final String sourceUrl;
  final String category;

  EventData({
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.time,
    required this.price,
    required this.imageUrl,
    required this.source,
    required this.sourceUrl,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'time': time,
      'price': price,
      'imageUrl': imageUrl,
      'source': source,
      'sourceUrl': sourceUrl,
      'category': category,
    };
  }
}

// Абстрактный класс для парсеров
abstract class EventScraper {
  String get sourceName;
  Future<List<EventData>> scrapeEvents({int limit = 50});
  Future<EventData?> scrapeEventDetail(String url);
}

// Парсер для KudaGo
class KudagoScraper extends EventScraper {
  @override
  String get sourceName => 'KudaGo';

  @override
  Future<List<EventData>> scrapeEvents({int limit = 50}) async {
    try {
      // KudaGo API endpoint для получения событий
      final response = await http.get(
        Uri.parse('https://kudago.com/public-api/v1.4/events/?location=msk&actual_since=${DateTime.now().millisecondsSinceEpoch ~/ 1000}&page_size=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> events = data['results'] ?? [];
        
        return events.map((event) {
          return EventData(
            title: event['title'] ?? 'Без названия',
            description: event['description'] ?? 'Описание отсутствует',
            location: event['place']?['name'] ?? 'Место не указано',
            date: _formatDate(event['dates']?[0]?['start']),
            time: _formatTime(event['dates']?[0]?['start']),
            price: event['price'] ?? 'Цена не указана',
            imageUrl: event['images']?[0]?['image'] ?? '',
            source: sourceName,
            sourceUrl: event['site_url'] ?? '',
            category: event['categories']?[0]?['name'] ?? 'Разное',
          );
        }).toList();
      }
    } catch (e) {
      print('Error scraping KudaGo events: $e');
    }
    return [];
  }

  @override
  Future<EventData?> scrapeEventDetail(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        final String? title = document.querySelector('h1')?.text.trim();
        final String? description = document.querySelector('.content-html')?.text.trim();
        final String? price = document.querySelector('.price')?.text.trim();
        final String? location = document.querySelector('.place-name')?.text.trim();
        
        String date = 'N/A';
        String time = 'N/A';
        final scheduleRows = document.querySelectorAll('.schedule-table tr');
        if (scheduleRows.isNotEmpty && scheduleRows.length > 1) {
          final firstRowCells = scheduleRows[1].querySelectorAll('td');
          if (firstRowCells.length >= 2) {
            date = firstRowCells[0].text.trim();
            time = firstRowCells[1].text.trim();
          }
        }

        return EventData(
          title: title ?? 'N/A',
          description: description ?? 'N/A',
          location: location ?? 'N/A',
          date: date,
          time: time,
          price: price ?? 'N/A',
          imageUrl: 'N/A',
          source: sourceName,
          sourceUrl: url,
          category: 'Разное',
        );
      }
    } catch (e) {
      print('Error scraping KudaGo event detail: $e');
    }
    return null;
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return 'Дата не указана';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return 'Время не указано';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Парсер для Afisha.ru
class AfishaScraper extends EventScraper {
  @override
  String get sourceName => 'Afisha.ru';

  @override
  Future<List<EventData>> scrapeEvents({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.afisha.ru/msk/schedule_cinema/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final events = <EventData>[];
        
        // Парсим события с главной страницы афиши
        final eventElements = document.querySelectorAll('.b-posters__item');
        
        for (var element in eventElements.take(limit)) {
          final titleElement = element.querySelector('.b-posters__title a');
          final title = titleElement?.text.trim() ?? 'Без названия';
          final link = titleElement?.attributes['href'] ?? '';
          
          final descriptionElement = element.querySelector('.b-posters__text');
          final description = descriptionElement?.text.trim() ?? 'Описание отсутствует';
          
          final imageElement = element.querySelector('img');
          final imageUrl = imageElement?.attributes['src'] ?? '';
          
          final locationElement = element.querySelector('.b-posters__place');
          final location = locationElement?.text.trim() ?? 'Место не указано';
          
          final dateElement = element.querySelector('.b-posters__date');
          final date = dateElement?.text.trim() ?? 'Дата не указана';
          
          events.add(EventData(
            title: title,
            description: description,
            location: location,
            date: date,
            time: 'Время не указано',
            price: 'Цена не указана',
            imageUrl: imageUrl.isNotEmpty ? 'https://www.afisha.ru$imageUrl' : '',
            source: sourceName,
            sourceUrl: link.isNotEmpty ? 'https://www.afisha.ru$link' : '',
            category: 'Кино',
          ));
        }
        
        return events;
      }
    } catch (e) {
      print('Error scraping Afisha events: $e');
    }
    return [];
  }

  @override
  Future<EventData?> scrapeEventDetail(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        final title = document.querySelector('h1')?.text.trim() ?? 'Без названия';
        final description = document.querySelector('.b-posters__text')?.text.trim() ?? 'Описание отсутствует';
        final location = document.querySelector('.b-posters__place')?.text.trim() ?? 'Место не указано';
        final imageElement = document.querySelector('.b-posters__image img');
        final imageUrl = imageElement?.attributes['src'] ?? '';
        
        return EventData(
          title: title,
          description: description,
          location: location,
          date: 'Дата не указана',
          time: 'Время не указано',
          price: 'Цена не указана',
          imageUrl: imageUrl.isNotEmpty ? 'https://www.afisha.ru$imageUrl' : '',
          source: sourceName,
          sourceUrl: url,
          category: 'Кино',
        );
      }
    } catch (e) {
      print('Error scraping Afisha event detail: $e');
    }
    return null;
  }
}

// Парсер для Bilet.mos
class BiletMosScraper extends EventScraper {
  @override
  String get sourceName => 'Bilet.mos';

  @override
  Future<List<EventData>> scrapeEvents({int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('https://bilet.mos.ru/events'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final events = <EventData>[];
        
        // Парсим события с главной страницы
        final eventElements = document.querySelectorAll('.event-card');
        
        for (var element in eventElements.take(limit)) {
          final titleElement = element.querySelector('.event-title');
          final title = titleElement?.text.trim() ?? 'Без названия';
          
          final linkElement = element.querySelector('a');
          final link = linkElement?.attributes['href'] ?? '';
          
          final descriptionElement = element.querySelector('.event-description');
          final description = descriptionElement?.text.trim() ?? 'Описание отсутствует';
          
          final imageElement = element.querySelector('img');
          final imageUrl = imageElement?.attributes['src'] ?? '';
          
          final locationElement = element.querySelector('.event-location');
          final location = locationElement?.text.trim() ?? 'Место не указано';
          
          final dateElement = element.querySelector('.event-date');
          final date = dateElement?.text.trim() ?? 'Дата не указана';
          
          final priceElement = element.querySelector('.event-price');
          final price = priceElement?.text.trim() ?? 'Цена не указана';
          
          events.add(EventData(
            title: title,
            description: description,
            location: location,
            date: date,
            time: 'Время не указано',
            price: price,
            imageUrl: imageUrl.isNotEmpty ? 'https://bilet.mos.ru$imageUrl' : '',
            source: sourceName,
            sourceUrl: link.isNotEmpty ? 'https://bilet.mos.ru$link' : '',
            category: 'Разное',
          ));
        }
        
        return events;
      }
    } catch (e) {
      print('Error scraping Bilet.mos events: $e');
    }
    return [];
  }

  @override
  Future<EventData?> scrapeEventDetail(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        
        final title = document.querySelector('h1')?.text.trim() ?? 'Без названия';
        final description = document.querySelector('.event-description')?.text.trim() ?? 'Описание отсутствует';
        final location = document.querySelector('.event-location')?.text.trim() ?? 'Место не указано';
        final imageElement = document.querySelector('.event-image img');
        final imageUrl = imageElement?.attributes['src'] ?? '';
        final price = document.querySelector('.event-price')?.text.trim() ?? 'Цена не указана';
        
        return EventData(
          title: title,
          description: description,
          location: location,
          date: 'Дата не указана',
          time: 'Время не указано',
          price: price,
          imageUrl: imageUrl.isNotEmpty ? 'https://bilet.mos.ru$imageUrl' : '',
          source: sourceName,
          sourceUrl: url,
          category: 'Разное',
        );
      }
    } catch (e) {
      print('Error scraping Bilet.mos event detail: $e');
    }
    return null;
  }
}

// Главный класс для управления всеми парсерами
class EventScrapingService {
  static final List<EventScraper> _scrapers = [
    KudagoScraper(),
    AfishaScraper(),
    BiletMosScraper(),
  ];

  static Future<List<EventData>> scrapeAllSources({int limitPerSource = 20}) async {
    final allEvents = <EventData>[];
    
    for (final scraper in _scrapers) {
      try {
        print('Scraping events from ${scraper.sourceName}...');
        final events = await scraper.scrapeEvents(limit: limitPerSource);
        allEvents.addAll(events);
        print('Found ${events.length} events from ${scraper.sourceName}');
      } catch (e) {
        print('Error scraping ${scraper.sourceName}: $e');
      }
    }
    
    // Удаляем дубликаты по названию и дате
    final uniqueEvents = <EventData>[];
    final seenEvents = <String>{};
    
    for (final event in allEvents) {
      final key = '${event.title}_${event.date}';
      if (!seenEvents.contains(key)) {
        seenEvents.add(key);
        uniqueEvents.add(event);
      }
    }
    
    print('Total unique events found: ${uniqueEvents.length}');
    return uniqueEvents;
  }

  static Future<EventData?> scrapeEventDetail(String url) async {
    for (final scraper in _scrapers) {
      if (url.contains(scraper.sourceName.toLowerCase().replaceAll('.', ''))) {
        return await scraper.scrapeEventDetail(url);
      }
    }
    return null;
  }

  static List<String> get availableSources => _scrapers.map((s) => s.sourceName).toList();
}
