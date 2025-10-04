import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class Ticket {
  final String id;
  final String eventId;
  final String eventTitle;
  final String venueName;
  final String date;
  final String time;
  final String section;
  final String row;
  final String seat;
  final double price;
  final String currency;
  final String status;
  final String? qrCode;
  final DateTime purchaseDate;
  final String userId;

  Ticket({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.venueName,
    required this.date,
    required this.time,
    required this.section,
    required this.row,
    required this.seat,
    required this.price,
    required this.currency,
    required this.status,
    this.qrCode,
    required this.purchaseDate,
    required this.userId,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      id: map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      eventTitle: map['eventTitle'] ?? '',
      venueName: map['venueName'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      section: map['section'] ?? '',
      row: map['row'] ?? '',
      seat: map['seat'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'RUB',
      status: map['status'] ?? 'pending',
      qrCode: map['qrCode'],
      purchaseDate: (map['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'venueName': venueName,
      'date': date,
      'time': time,
      'section': section,
      'row': row,
      'seat': seat,
      'price': price,
      'currency': currency,
      'status': status,
      'qrCode': qrCode,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'userId': userId,
    };
  }
}

class PaymentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Rambler-kassa API configuration
  static const String _ramblerKassaApiUrl = 'https://api.rambler-kassa.ru/v1';
  static const String _ramblerKassaApiKey = 'YOUR_RAMBLER_KASSA_API_KEY'; // Заменить на реальный ключ
  
  // Yandex.Afisha API configuration
  static const String _yandexAfishaApiUrl = 'https://api.afisha.yandex.ru/v1';
  static const String _yandexAfishaApiKey = 'YOUR_YANDEX_AFISHA_API_KEY'; // Заменить на реальный ключ

  // Создание платежа через Rambler-kassa
  static Future<Map<String, dynamic>?> createRamblerKassaPayment({
    required String eventId,
    required String eventTitle,
    required double amount,
    required String currency,
    required String userId,
    required String userEmail,
    required String userPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_ramblerKassaApiUrl/payments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_ramblerKassaApiKey',
        },
        body: json.encode({
          'amount': (amount * 100).toInt(), // Конвертируем в копейки
          'currency': currency,
          'description': 'Билет на событие: $eventTitle',
          'metadata': {
            'eventId': eventId,
            'userId': userId,
          },
          'confirmation': {
            'type': 'redirect',
            'return_url': 'leisure_app://payment_success',
          },
          'capture_method': 'automatic',
          'receipt': {
            'customer': {
              'email': userEmail,
              'phone': userPhone,
            },
            'items': [
              {
                'description': 'Билет на событие: $eventTitle',
                'quantity': 1,
                'amount': {
                  'value': (amount * 100).toInt(),
                  'currency': currency,
                },
                'vat_code': 1,
              },
            ],
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('Rambler-kassa payment creation failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error creating Rambler-kassa payment: $e');
      return null;
    }
  }

  // Создание платежа через Yandex.Afisha
  static Future<Map<String, dynamic>?> createYandexAfishaPayment({
    required String eventId,
    required String eventTitle,
    required double amount,
    required String currency,
    required String userId,
    required String userEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_yandexAfishaApiUrl/tickets/purchase'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_yandexAfishaApiKey',
        },
        body: json.encode({
          'event_id': eventId,
          'amount': amount,
          'currency': currency,
          'user_id': userId,
          'user_email': userEmail,
          'description': 'Билет на событие: $eventTitle',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print('Yandex.Afisha payment creation failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error creating Yandex.Afisha payment: $e');
      return null;
    }
  }

  // Сохранение билета в Firestore
  static Future<void> saveTicket(Ticket ticket) async {
    try {
      await _firestore.collection('tickets').add(ticket.toMap());
    } catch (e) {
      print('Error saving ticket: $e');
      rethrow;
    }
  }

  // Получение билетов пользователя
  static Future<List<Ticket>> getUserTickets(String userId) async {
    try {
      final query = await _firestore
          .collection('tickets')
          .where('userId', isEqualTo: userId)
          .orderBy('purchaseDate', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Ticket.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting user tickets: $e');
      return [];
    }
  }

  // Обновление статуса билета
  static Future<void> updateTicketStatus(String ticketId, String status) async {
    try {
      await _firestore.collection('tickets').doc(ticketId).update({
        'status': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating ticket status: $e');
      rethrow;
    }
  }

  // Проверка статуса платежа
  static Future<Map<String, dynamic>?> checkPaymentStatus(String paymentId) async {
    try {
      // Проверяем статус в Rambler-kassa
      final ramblerResponse = await http.get(
        Uri.parse('$_ramblerKassaApiUrl/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer $_ramblerKassaApiKey',
        },
      );

      if (ramblerResponse.statusCode == 200) {
        return json.decode(ramblerResponse.body);
      }

      // Если не найдено в Rambler-kassa, проверяем Yandex.Afisha
      final yandexResponse = await http.get(
        Uri.parse('$_yandexAfishaApiUrl/tickets/$paymentId'),
        headers: {
          'Authorization': 'Bearer $_yandexAfishaApiKey',
        },
      );

      if (yandexResponse.statusCode == 200) {
        return json.decode(yandexResponse.body);
      }

      return null;
    } catch (e) {
      print('Error checking payment status: $e');
      return null;
    }
  }

  // Отмена билета
  static Future<bool> cancelTicket(String ticketId) async {
    try {
      // Обновляем статус в Firestore
      await _firestore.collection('tickets').doc(ticketId).update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.now(),
      });

      // Здесь можно добавить логику отмены в платежной системе
      // В зависимости от того, через какую систему был куплен билет

      return true;
    } catch (e) {
      print('Error cancelling ticket: $e');
      return false;
    }
  }

  // Получение доступных мест для события
  static Future<List<Map<String, dynamic>>> getAvailableSeats(String eventId) async {
    try {
      // В реальном приложении здесь будет запрос к API билетной системы
      // Пока возвращаем моковые данные
      return [
        {
          'section': 'Партер',
          'row': '1',
          'seat': '1',
          'price': 2500.0,
          'currency': 'RUB',
          'available': true,
        },
        {
          'section': 'Партер',
          'row': '1',
          'seat': '2',
          'price': 2500.0,
          'currency': 'RUB',
          'available': true,
        },
        {
          'section': 'Балкон',
          'row': '1',
          'seat': '1',
          'price': 1500.0,
          'currency': 'RUB',
          'available': true,
        },
        {
          'section': 'Балкон',
          'row': '1',
          'seat': '2',
          'price': 1500.0,
          'currency': 'RUB',
          'available': false,
        },
      ];
    } catch (e) {
      print('Error getting available seats: $e');
      return [];
    }
  }

  // Создание QR-кода для билета
  static Future<String?> generateQRCode(Ticket ticket) async {
    try {
      // В реальном приложении здесь будет генерация QR-кода
      // Пока возвращаем моковый QR-код
      final qrData = {
        'ticketId': ticket.id,
        'eventId': ticket.eventId,
        'userId': ticket.userId,
        'purchaseDate': ticket.purchaseDate.toIso8601String(),
      };
      
      return json.encode(qrData);
    } catch (e) {
      print('Error generating QR code: $e');
      return null;
    }
  }

  // Валидация билета по QR-коду
  static Future<bool> validateTicket(String qrCode) async {
    try {
      final qrData = json.decode(qrCode);
      final ticketId = qrData['ticketId'];
      
      final ticketDoc = await _firestore.collection('tickets').doc(ticketId).get();
      if (!ticketDoc.exists) {
        return false;
      }
      
      final ticket = Ticket.fromMap(ticketDoc.data()!);
      return ticket.status == 'confirmed';
    } catch (e) {
      print('Error validating ticket: $e');
      return false;
    }
  }
}
