import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_controller.dart';

class EditBioPage extends StatefulWidget {
  final String currentBio;

  const EditBioPage({
    super.key,
    required this.currentBio,
  });

  @override
  State<EditBioPage> createState() => _EditBioPageState();
}

class _EditBioPageState extends State<EditBioPage> {
  final ProfileController profileController = Get.find<ProfileController>();
  final TextEditingController _bioController = TextEditingController();
  bool _isSaving = false;
  final int _maxBioLength = 150;

  @override
  void initState() {
    super.initState();
    _bioController.text = widget.currentBio;
    _bioController.addListener(_updateCharacterCount);
  }

  void _updateCharacterCount() {
    setState(() {});
  }

  @override
  void dispose() {
    _bioController.removeListener(_updateCharacterCount);
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveBio() async {
    final bio = _bioController.text.trim();
    
    // Валидация
    if (bio.isEmpty) {
      Get.snackbar(
        'Error',
        'Bio cannot be empty',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    
    if (bio.length > _maxBioLength) {
      Get.snackbar(
        'Error',
        'Bio cannot exceed $_maxBioLength characters',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await profileController.updateBio(bio);
      Get.back(result: bio);
      
      Get.snackbar(
        'Success',
        'Bio updated successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save bio: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _bioController.text.length;
    final bool isOverLimit = currentLength > _maxBioLength;
    final bool isEmpty = _bioController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Edit Bio",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || isOverLimit || isEmpty) ? null : _saveBio,
            child: Text(
              'Save',
              style: TextStyle(
                color: (_isSaving || isOverLimit || isEmpty) 
                    ? Colors.grey 
                    : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tell people about yourself',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will appear on your profile',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            
            TextField(
              controller: _bioController,
              maxLines: 5,
              maxLength: _maxBioLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (!_isSaving && !isOverLimit && !isEmpty) {
                  _saveBio();
                }
              },
              buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) {
                return Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(
                    color: isOverLimit ? Colors.red : Colors.grey,
                    fontWeight: isOverLimit ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
              decoration: InputDecoration(
                hintText: "Write something about yourself...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
            
            if (isOverLimit)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "Bio exceeds maximum length by ${currentLength - _maxBioLength} characters",
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_isSaving || isOverLimit || isEmpty) 
                      ? Colors.grey 
                      : Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: (_isSaving || isOverLimit || isEmpty) ? null : _saveBio,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save Bio",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}