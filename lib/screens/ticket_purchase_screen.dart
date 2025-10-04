import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leisure_app/services/payment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TicketPurchaseScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String eventDate;
  final String eventTime;
  final String venueName;

  const TicketPurchaseScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.eventDate,
    required this.eventTime,
    required this.venueName,
  });

  @override
  State<TicketPurchaseScreen> createState() => _TicketPurchaseScreenState();
}

class _TicketPurchaseScreenState extends State<TicketPurchaseScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  List<Map<String, dynamic>> _availableSeats = [];
  Map<String, dynamic>? _selectedSeat;
  bool _isLoading = false;
  bool _isPurchasing = false;
  String _selectedPaymentMethod = 'rambler_kassa';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadAvailableSeats();
    _loadUserData();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSeats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final seats = await PaymentService.getAvailableSeats(widget.eventId);
      setState(() {
        _availableSeats = seats;
      });
    } catch (e) {
      _showSnackBar('Ошибка загрузки мест: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      
      // Загружаем телефон из профиля пользователя
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          _phoneController.text = data?['phone'] ?? '';
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _purchaseTicket() async {
    if (_selectedSeat == null) {
      _showSnackBar('Выберите место', Colors.orange);
      return;
    }

    if (_emailController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar('Заполните все поля', Colors.orange);
      return;
    }

    setState(() {
      _isPurchasing = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('Пользователь не авторизован', Colors.red);
        return;
      }

      Map<String, dynamic>? paymentResult;
      
      if (_selectedPaymentMethod == 'rambler_kassa') {
        paymentResult = await PaymentService.createRamblerKassaPayment(
          eventId: widget.eventId,
          eventTitle: widget.eventTitle,
          amount: _selectedSeat!['price'].toDouble(),
          currency: _selectedSeat!['currency'],
          userId: user.uid,
          userEmail: _emailController.text,
          userPhone: _phoneController.text,
        );
      } else {
        paymentResult = await PaymentService.createYandexAfishaPayment(
          eventId: widget.eventId,
          eventTitle: widget.eventTitle,
          amount: _selectedSeat!['price'].toDouble(),
          currency: _selectedSeat!['currency'],
          userId: user.uid,
          userEmail: _emailController.text,
        );
      }

      if (paymentResult != null) {
        // Создаем билет
        final ticket = Ticket(
          id: paymentResult['id'] ?? '',
          eventId: widget.eventId,
          eventTitle: widget.eventTitle,
          venueName: widget.venueName,
          date: widget.eventDate,
          time: widget.eventTime,
          section: _selectedSeat!['section'],
          row: _selectedSeat!['row'],
          seat: _selectedSeat!['seat'],
          price: _selectedSeat!['price'].toDouble(),
          currency: _selectedSeat!['currency'],
          status: 'pending',
          purchaseDate: DateTime.now(),
          userId: user.uid,
        );

        await PaymentService.saveTicket(ticket);

        _showSnackBar('Билет успешно создан!', Colors.green);
        
        // Перенаправляем на страницу оплаты или успеха
        if (paymentResult['confirmation'] != null) {
          // Открываем страницу оплаты
          _showPaymentDialog(paymentResult);
        } else {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackBar('Ошибка создания платежа', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Ошибка покупки билета: $e', Colors.red);
    } finally {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  void _showPaymentDialog(Map<String, dynamic> paymentData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Оплата билета'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Перейдите на страницу оплаты для завершения покупки'),
            const SizedBox(height: 16),
            if (paymentData['confirmation']?['confirmation_url'] != null)
              ElevatedButton(
                onPressed: () {
                  // В реальном приложении здесь будет открытие браузера
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text('Перейти к оплате'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, false);
            },
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFEC4899),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  // Content
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event info
                                  _buildEventInfo(),
                                  const SizedBox(height: 24),
                                  // Seat selection
                                  _buildSeatSelection(),
                                  const SizedBox(height: 24),
                                  // Contact info
                                  _buildContactInfo(),
                                  const SizedBox(height: 24),
                                  // Payment method
                                  _buildPaymentMethod(),
                                  const SizedBox(height: 32),
                                  // Purchase button
                                  _buildPurchaseButton(),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Покупка билета',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eventTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.venueName,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.eventDate} в ${widget.eventTime}',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Выберите место',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _availableSeats.length,
          itemBuilder: (context, index) {
            final seat = _availableSeats[index];
            final isSelected = _selectedSeat == seat;
            final isAvailable = seat['available'] == true;

            return GestureDetector(
              onTap: isAvailable ? () {
                setState(() {
                  _selectedSeat = seat;
                });
              } : null,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : isAvailable
                          ? const Color(0xFFF8FAFC)
                          : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${seat['section']} ${seat['row']}-${seat['seat']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${seat['price']} ${seat['currency']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white70
                              : isAvailable
                                  ? const Color(0xFF64748B)
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Контактная информация',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Телефон',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Способ оплаты',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        RadioListTile<String>(
          title: const Text('Rambler-kassa'),
          subtitle: const Text('Банковские карты, электронные деньги'),
          value: 'rambler_kassa',
          groupValue: _selectedPaymentMethod,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          activeColor: const Color(0xFF6366F1),
        ),
        RadioListTile<String>(
          title: const Text('Yandex.Afisha'),
          subtitle: const Text('Яндекс.Касса, банковские карты'),
          value: 'yandex_afisha',
          groupValue: _selectedPaymentMethod,
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethod = value!;
            });
          },
          activeColor: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final totalPrice = _selectedSeat?['price'] ?? 0.0;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '$totalPrice RUB',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isPurchasing ? null : _purchaseTicket,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isPurchasing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Купить билет',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
