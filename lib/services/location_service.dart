import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class Location {
  final String id;
  final String name;
  final String city;
  final String region;
  final String country;
  final double latitude;
  final double longitude;
  final String address;
  final String? description;
  final List<String> categories;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  Location({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.description,
    required this.categories,
    this.imageUrl,
    this.metadata,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      city: map['city'] ?? '',
      region: map['region'] ?? '',
      country: map['country'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      description: map['description'],
      categories: List<String>.from(map['categories'] ?? []),
      imageUrl: map['imageUrl'],
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'description': description,
      'categories': categories,
      'imageUrl': imageUrl,
      'metadata': metadata,
    };
  }

  double distanceTo(double lat, double lng) {
    return Geolocator.distanceBetween(latitude, longitude, lat, lng);
  }
}

class Venue {
  final String id;
  final String name;
  final String locationId;
  final String venueType;
  final int capacity;
  final String? description;
  final List<String> amenities;
  final String? imageUrl;
  final Map<String, dynamic>? contactInfo;
  final Map<String, dynamic>? pricing;
  final bool isActive;

  Venue({
    required this.id,
    required this.name,
    required this.locationId,
    required this.venueType,
    required this.capacity,
    this.description,
    required this.amenities,
    this.imageUrl,
    this.contactInfo,
    this.pricing,
    this.isActive = true,
  });

  factory Venue.fromMap(Map<String, dynamic> map) {
    return Venue(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      locationId: map['locationId'] ?? '',
      venueType: map['venueType'] ?? '',
      capacity: map['capacity'] ?? 0,
      description: map['description'],
      amenities: List<String>.from(map['amenities'] ?? []),
      imageUrl: map['imageUrl'],
      contactInfo: map['contactInfo'],
      pricing: map['pricing'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'locationId': locationId,
      'venueType': venueType,
      'capacity': capacity,
      'description': description,
      'amenities': amenities,
      'imageUrl': imageUrl,
      'contactInfo': contactInfo,
      'pricing': pricing,
      'isActive': isActive,
    };
  }
}

class LocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Получение всех городов
  static Future<List<String>> getCities() async {
    try {
      final query = await _firestore
          .collection('locations')
          .orderBy('city')
          .get();
      
      final cities = <String>{};
      for (final doc in query.docs) {
        final data = doc.data();
        cities.add(data['city'] ?? '');
      }
      
      return cities.toList()..sort();
    } catch (e) {
      print('Error getting cities: $e');
      return [];
    }
  }

  // Получение локаций по городу
  static Future<List<Location>> getLocationsByCity(String city) async {
    try {
      final query = await _firestore
          .collection('locations')
          .where('city', isEqualTo: city)
          .orderBy('name')
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Location.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting locations by city: $e');
      return [];
    }
  }

  // Поиск локаций по названию
  static Future<List<Location>> searchLocations(String query) async {
    try {
      final locationsQuery = await _firestore
          .collection('locations')
          .orderBy('name')
          .get();
      
      final results = <Location>[];
      final searchTerm = query.toLowerCase();
      
      for (final doc in locationsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final location = Location.fromMap(data);
        
        if (location.name.toLowerCase().contains(searchTerm) ||
            location.city.toLowerCase().contains(searchTerm) ||
            location.address.toLowerCase().contains(searchTerm)) {
          results.add(location);
        }
      }
      
      return results;
    } catch (e) {
      print('Error searching locations: $e');
      return [];
    }
  }

  // Получение локаций рядом с пользователем
  static Future<List<Location>> getNearbyLocations(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    try {
      // Получаем все локации (в реальном приложении лучше использовать геокодинг)
      final query = await _firestore
          .collection('locations')
          .get();
      
      final nearbyLocations = <Location>[];
      
      for (final doc in query.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        final location = Location.fromMap(data);
        
        final distance = location.distanceTo(latitude, longitude);
        if (distance <= radiusKm * 1000) { // Конвертируем км в метры
          nearbyLocations.add(location);
        }
      }
      
      // Сортируем по расстоянию
      nearbyLocations.sort((a, b) {
        final distanceA = a.distanceTo(latitude, longitude);
        final distanceB = b.distanceTo(latitude, longitude);
        return distanceA.compareTo(distanceB);
      });
      
      return nearbyLocations;
    } catch (e) {
      print('Error getting nearby locations: $e');
      return [];
    }
  }

  // Получение площадок по локации
  static Future<List<Venue>> getVenuesByLocation(String locationId) async {
    try {
      final query = await _firestore
          .collection('venues')
          .where('locationId', isEqualTo: locationId)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Venue.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting venues by location: $e');
      return [];
    }
  }

  // Получение площадок по типу
  static Future<List<Venue>> getVenuesByType(String venueType) async {
    try {
      final query = await _firestore
          .collection('venues')
          .where('venueType', isEqualTo: venueType)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Venue.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting venues by type: $e');
      return [];
    }
  }

  // Добавление новой локации
  static Future<void> addLocation(Location location) async {
    try {
      await _firestore.collection('locations').add(location.toMap());
    } catch (e) {
      print('Error adding location: $e');
      rethrow;
    }
  }

  // Добавление новой площадки
  static Future<void> addVenue(Venue venue) async {
    try {
      await _firestore.collection('venues').add(venue.toMap());
    } catch (e) {
      print('Error adding venue: $e');
      rethrow;
    }
  }

  // Получение текущей позиции пользователя
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // Инициализация базовых данных локаций
  static Future<void> initializeLocationData() async {
    try {
      // Проверяем, есть ли уже данные
      final existingLocations = await _firestore.collection('locations').limit(1).get();
      if (existingLocations.docs.isNotEmpty) {
        return; // Данные уже есть
      }

      // Добавляем основные города России
      final cities = [
        {
          'name': 'Москва',
          'city': 'Москва',
          'region': 'Москва',
          'country': 'Россия',
          'latitude': 55.7558,
          'longitude': 37.6176,
          'address': 'Москва, Россия',
          'categories': ['Столица', 'Культура', 'Развлечения'],
        },
        {
          'name': 'Санкт-Петербург',
          'city': 'Санкт-Петербург',
          'region': 'Ленинградская область',
          'country': 'Россия',
          'latitude': 59.9311,
          'longitude': 30.3609,
          'address': 'Санкт-Петербург, Россия',
          'categories': ['Культура', 'История', 'Развлечения'],
        },
        {
          'name': 'Екатеринбург',
          'city': 'Екатеринбург',
          'region': 'Свердловская область',
          'country': 'Россия',
          'latitude': 56.8431,
          'longitude': 60.6454,
          'address': 'Екатеринбург, Россия',
          'categories': ['Культура', 'Бизнес'],
        },
        {
          'name': 'Новосибирск',
          'city': 'Новосибирск',
          'region': 'Новосибирская область',
          'country': 'Россия',
          'latitude': 55.0084,
          'longitude': 82.9357,
          'address': 'Новосибирск, Россия',
          'categories': ['Культура', 'Наука'],
        },
        {
          'name': 'Казань',
          'city': 'Казань',
          'region': 'Республика Татарстан',
          'country': 'Россия',
          'latitude': 55.8304,
          'longitude': 49.0661,
          'address': 'Казань, Россия',
          'categories': ['Культура', 'Спорт'],
        },
      ];

      for (final cityData in cities) {
        await _firestore.collection('locations').add(cityData);
      }

      print('Location data initialized successfully');
    } catch (e) {
      print('Error initializing location data: $e');
    }
  }
}
