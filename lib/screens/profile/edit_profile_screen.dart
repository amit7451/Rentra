import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../app/theme.dart';
import '../../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel userModel;

  const EditProfileScreen({super.key, required this.userModel});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _emailController;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;
  File? _imageFile;
  bool _isLoading = false;
  final _picker = ImagePicker();
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userModel.name);
    _phoneNumberController = TextEditingController(
      text: widget.userModel.phoneNumber,
    );
    _emailController = TextEditingController(text: widget.userModel.email);
    _selectedDateOfBirth = widget.userModel.dateOfBirth;
    _selectedGender = widget.userModel.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? photoUrl = widget.userModel.photoUrl;

      if (_imageFile != null) {
        photoUrl = await _cloudinaryService.uploadImage(_imageFile!);
      }

      final updatedData = {
        'name': _nameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'dateOfBirth': _selectedDateOfBirth?.millisecondsSinceEpoch,
        'gender': _selectedGender,
        'photoUrl': photoUrl,
      };

      await _firestoreService.updateUser(widget.userModel.uid, updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (widget.userModel.photoUrl != null
                                  ? NetworkImage(widget.userModel.photoUrl!)
                                  : null)
                              as ImageProvider?,
                    child:
                        (_imageFile == null &&
                            widget.userModel.photoUrl == null)
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: AppTheme.primaryRed,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryRed,
                      child: IconButton(
                        icon: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              IgnorePointer(
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: AppTheme.lightGrey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: ['Male', 'Female', 'Prefer not to say', 'Other']
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (newValue) =>
                    setState(() => _selectedGender = newValue),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDateOfBirth ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDateOfBirth = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _selectedDateOfBirth == null
                        ? 'Select Date'
                        : DateFormat(
                            'dd/MM/yyyy',
                          ).format(_selectedDateOfBirth!),
                    style: const TextStyle(color: AppTheme.black),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Save Changes',
                onPressed: _updateProfile,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
