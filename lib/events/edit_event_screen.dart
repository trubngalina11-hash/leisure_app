import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leisure_app/events/event_list_screen.dart'; // Import EventCategoryCache

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditEventScreen({super.key, required this.eventId, required this.eventData});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String? _selectedCategory;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _socialLinkController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<File> _pickedImages = []; // For new images to upload
  List<String> _existingImageUrls = []; // For images already in storage
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _eventCategories = EventCategoryCache.categories; // Use cached categories

  final List<Map<String, String>> _eventSessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _populateForm();
  }

  void _populateForm() {
    _titleController.text = widget.eventData['title'] ?? '';
    _descriptionController.text = widget.eventData['description'] ?? '';
    _locationController.text = widget.eventData['location'] ?? '';
    _selectedCategory = widget.eventData['category'] as String?;
    _dateController.text = widget.eventData['date'] ?? '';
    _timeController.text = widget.eventData['time'] ?? '';
    _priceController.text = widget.eventData['price'] ?? '';
    _contactPersonController.text = widget.eventData['contactPerson'] ?? '';
    _contactPhoneController.text = widget.eventData['contactPhone'] ?? '';
    _socialLinkController.text = widget.eventData['socialLink'] ?? '';
    _maxParticipantsController.text = widget.eventData['maxParticipants']?.toString() ?? '';

    if (widget.eventData['sessions'] != null) {
      for (var session in widget.eventData['sessions']) {
        _eventSessions.add({
          'date': session['date'] ?? '',
          'time': session['time'] ?? '',
        });
      }
    }
    if (widget.eventData['imageUrls'] != null) {
      _existingImageUrls = List<String>.from(widget.eventData['imageUrls']);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _priceController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _socialLinkController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage(imageQuality: 50);
    if (pickedFiles != null) {
      setState(() {
        _pickedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)).toList());
      });
    }
  }

  void _removePickedImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
    // TODO: Consider deleting from Firebase Storage as well
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateFormat('dd.MM.yyyy').parse(_dateController.text)
          : DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timeController.text.isNotEmpty
          ? TimeOfDay.fromDateTime(DateFormat.jm().parse(_timeController.text))
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  void _addSession() {
    setState(() {
      _eventSessions.add({'date': '', 'time': ''});
    });
  }

  void _removeSession(int index) {
    setState(() {
      _eventSessions.removeAt(index);
    });
  }

  Future<void> _selectSessionDate(BuildContext context, int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _eventSessions[index]['date']!.isNotEmpty
          ? DateFormat('dd.MM.yyyy').parse(_eventSessions[index]['date']!)
          : DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() {
        _eventSessions[index]['date'] = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _selectSessionTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _eventSessions[index]['time']!.isNotEmpty
          ? TimeOfDay.fromDateTime(DateFormat.jm().parse(_eventSessions[index]['time']!))
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _eventSessions[index]['time'] = picked.format(context);
      });
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to edit an event.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload new images to Firebase Storage
      List<String> newImageUrls = [];
      for (File imageFile in _pickedImages) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('event_images')
            .child('${DateTime.now().toIso8601String()}_${_pickedImages.indexOf(imageFile)}.jpg');
        await ref.putFile(imageFile);
        final url = await ref.getDownloadURL();
        newImageUrls.add(url);
      }

      // Combine existing and new image URLs
      List<String> allImageUrls = [..._existingImageUrls, ...newImageUrls];

      // Update event data in Firestore
      await _firestore.collection('events').doc(widget.eventId).update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _selectedCategory,
        'date': _dateController.text.trim(),
        'time': _timeController.text.trim(),
        'price': _priceController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'socialLink': _socialLinkController.text.trim(),
        'maxParticipants': int.tryParse(_maxParticipantsController.text.trim()) ?? 0,
        'sessions': _eventSessions,
        'imageUrls': allImageUrls, // Update with all image URLs
        // organizerId and timestamp should not change on update
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $e')),
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
        title: const Text('Edit Event'),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Edit Event Details',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Event Title',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.title),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a title';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Event Description',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.description),
                                  filled: true,
                                  fillColor: Colors.white70,
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a description';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.location_on),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a location';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white70,
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
                                    _selectedCategory = newValue; // Update selected category
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a category';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                onTap: () => _selectDate(context),
                                decoration: InputDecoration(
                                  labelText: 'Date',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white70,
                                  prefixIcon: const Icon(Icons.calendar_today),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a date';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _timeController,
                                readOnly: true,
                                onTap: () => _selectTime(context),
                                decoration: InputDecoration(
                                  labelText: 'Time',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white70,
                                  prefixIcon: const Icon(Icons.access_time),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a time';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Price (e.g., "Free" or "\$10.00")',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.attach_money),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                keyboardType: TextInputType.text,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a price';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _contactPersonController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Person',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a contact person';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _contactPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Contact Phone',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.phone),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a contact phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _socialLinkController,
                                decoration: const InputDecoration(
                                  labelText: 'Social Media Link',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.link),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _maxParticipantsController,
                                decoration: const InputDecoration(
                                  labelText: 'Max Participants (optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                                  prefixIcon: Icon(Icons.group),
                                  filled: true,
                                  fillColor: Colors.white70,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Event Images:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                              ),
                              const SizedBox(height: 10),
                              // Display existing images
                              if (_existingImageUrls.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _existingImageUrls.length,
                                    itemBuilder: (context, index) {
                                      return Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                _existingImageUrls[index],
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () => _removeExistingImage(index),
                                              child: CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.red.shade400,
                                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              // Display newly picked images
                              if (_pickedImages.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _pickedImages.length,
                                    itemBuilder: (context, index) {
                                      return Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                _pickedImages[index],
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () => _removePickedImage(index),
                                              child: CircleAvatar(
                                                radius: 12,
                                                backgroundColor: Colors.red.shade400,
                                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.image, color: Colors.deepPurple),
                                label: const Text('Pick More Images', style: TextStyle(color: Colors.deepPurple)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Event Sessions:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                              ),
                              const SizedBox(height: 10),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _eventSessions.length,
                                itemBuilder: (context, index) {
                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              readOnly: true,
                                              onTap: () => _selectSessionDate(context, index),
                                              controller: TextEditingController(text: _eventSessions[index]['date']!),
                                              decoration: InputDecoration(
                                                labelText: 'Date',
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey.shade100,
                                                prefixIcon: const Icon(Icons.calendar_today),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextFormField(
                                              readOnly: true,
                                              onTap: () => _selectSessionTime(context, index),
                                              controller: TextEditingController(text: _eventSessions[index]['time']!),
                                              decoration: InputDecoration(
                                                labelText: 'Time',
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey.shade100,
                                                prefixIcon: const Icon(Icons.access_time),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                                            onPressed: () => _removeSession(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              TextButton.icon(
                                onPressed: _addSession,
                                icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                                label: const Text('Add Session', style: TextStyle(color: Colors.deepPurple)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              const SizedBox(height: 30),
                              ElevatedButton.icon(
                                onPressed: _updateEvent,
                                icon: const Icon(Icons.save, color: Colors.white),
                                label: const Text('Update Event', style: TextStyle(color: Colors.white)),
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
          ),
        ],
      ),
    );
  }
}
