import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../controllers/profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String currentBio;
  final String currentAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
    required this.currentAvatarUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final ProfileController _profileController = Get.find<ProfileController>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _selectedImage;
  String? _avatarUrl;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  
  // 🔥 ДЛЯ ОТСЛЕЖИВАНИЯ ИЗМЕНЕНИЙ
  bool get _hasUnsavedChanges {
    final usernameChanged = _usernameController.text.trim() != widget.currentUsername;
    final bioChanged = _bioController.text.trim() != widget.currentBio;
    final imageChanged = _selectedImage != null;
    return usernameChanged || bioChanged || imageChanged;
  }

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.currentUsername;
    _bioController.text = widget.currentBio;
    _avatarUrl = widget.currentAvatarUrl;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // 🔥 ДИАЛОГ ПОДТВЕРЖДЕНИЯ ПРИ ВЫХОДЕ
  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Discard Changes?',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Discard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
    return result ?? false;
  }

  // 🔥 ПРОВЕРКА РАЗМЕРА ФАЙЛА (MAX 5MB)
  Future<bool> _validateImageSize(XFile file) async {
    final fileSize = await file.length();
    const maxSize = 5 * 1024 * 1024; // 5MB
    
    if (fileSize > maxSize) {
      Get.snackbar(
        'Error',
        'Image too large. Maximum size is 5MB',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return false;
    }
    return true;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 🔥 ПРОВЕРКА РАЗМЕРА
        final isValid = await _validateImageSize(pickedFile);
        if (!isValid) return;

        setState(() {
          _selectedImage = File(pickedFile.path);
          _avatarUrl = null;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      Get.snackbar(
        'Error',
        'Failed to pick image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      setState(() => _isUploadingImage = true);

      final userId = _auth.currentUser!.uid;
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('user_avatars/$userId/$fileName');

      final uploadTask = await ref.putFile(_selectedImage!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() => _isUploadingImage = false);
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isUploadingImage = false);
      Get.snackbar(
        'Error',
        'Failed to upload photo',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    }
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    if (username == widget.currentUsername) return true;

    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.trim())
          .where(FieldPath.documentId, isNotEqualTo: _auth.currentUser!.uid)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    // Basic validation
    if (username.isEmpty) {
      Get.snackbar(
        'Error',
        'Username cannot be empty',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (username.length < 3) {
      Get.snackbar(
        'Error',
        'Username must be at least 3 characters',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (username.length > 30) {
      Get.snackbar(
        'Error',
        'Username cannot exceed 30 characters',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Validate username characters
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(username)) {
      Get.snackbar(
        'Error',
        'Username can only contain letters, numbers, dots and underscores',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? newAvatarUrl;

      // Upload new photo if exists
      if (_selectedImage != null) {
        newAvatarUrl = await _uploadImage();
        if (newAvatarUrl == null) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final userId = _auth.currentUser!.uid;
      
      // Check username availability if changed
      if (username != widget.currentUsername) {
        final isAvailable = await _checkUsernameAvailability(username);
        if (!isAvailable) {
          Get.snackbar(
            'Error',
            'This username is already taken',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      // 🔥 ИСПОЛЬЗУЕМ КОНТРОЛЛЕР ДЛЯ ОБНОВЛЕНИЯ
      await _profileController.updateProfile(
        newUsername: username,
        newBio: bio,
        newAvatarUrl: newAvatarUrl ?? widget.currentAvatarUrl,
      );

      print('✅ Profile updated successfully');
      print('👤 Username: $username');
      print('📝 Bio: $bio');
      print('🖼️ Avatar: ${newAvatarUrl ?? widget.currentAvatarUrl}');

      // Return result
      Get.back(result: {
        'username': username,
        'bio': bio,
        'avatarUrl': newAvatarUrl ?? widget.currentAvatarUrl,
      });

      Get.snackbar(
        'Success',
        'Profile updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      print('❌ Error saving profile: $e');
      Get.snackbar(
        'Error',
        'Failed to save changes: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      )
                    : (_avatarUrl?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: _avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
              ),
            ),
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                onPressed: _isUploadingImage ? null : _pickImage,
                tooltip: 'Change profile photo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _pickImage,
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
          child: const Text(
            'Change profile photo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    int? maxLines = 1,
    int? maxLength,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(14),
            counterText: maxLength != null ? '${controller.text.length}/$maxLength' : null,
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges) {
          return await _showDiscardDialog();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () async {
              if (_hasUnsavedChanges) {
                final shouldPop = await _showDiscardDialog();
                if (shouldPop) {
                  Get.back();
                }
              } else {
                Get.back();
              }
            },
            tooltip: 'Close',
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                _buildAvatarSection(),
                const SizedBox(height: 32),

                // Username field
                _buildInputField(
                  label: 'Username',
                  controller: _usernameController,
                  maxLength: 30,
                  hintText: 'Enter username (letters, numbers, . _ only)',
                ),

                // Bio field
                _buildInputField(
                  label: 'Bio',
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 150,
                  hintText: 'Tell about yourself (max 150 characters)',
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}