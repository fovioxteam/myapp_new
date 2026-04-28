// lib/screens/upload_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_preview_screen.dart';
import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // 🔥 Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 🔥 PostController
  final PostController _postController = Get.find<PostController>();
  
  // 🔥 SELECTED FOLDER
  String _selectedFolder = 'Recents';
  final List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  
  // 🔥 MULTI-SELECT: ВЫБРАННЫЕ ИЗОБРАЖЕНИЯ С ПОРЯДКОВЫМ НОМЕРОМ
  final Map<AssetEntity, int> _selectedAssets = {};
  
  // 🔥 СПИСОК ВЫБРАННЫХ ФОТО В ПОРЯДКЕ ВЫБОРА (ДЛЯ ПРЕВЬЮ)
  final List<AssetEntity> _selectedAssetsOrder = [];
  
  // 🔥 ВСЕ ФОТО ИЗ ВЫБРАННОГО АЛЬБОМА
  final List<AssetEntity> _photos = [];
  
  // 🔥 ДЛЯ ПАГИНАЦИИ
  int _currentPage = 0;
  final int _pageSize = 40;
  bool _hasMore = true;
  bool _isLoading = false;

  // 🔥 ДЛЯ РАЗВОРАЧИВАНИЯ RECENTS
  bool _isRecentsExpanded = false;

  // 🔥 ПРАВА ДОСТУПА
  bool _hasPermission = false;
  bool _isLoadingPermission = true;
  String _permissionError = '';

  // 🔥 КЭШ ДЛЯ ФОТО (ОПТИМИЗАЦИЯ)
  final Map<AssetEntity, File?> _photoCache = {};

  // 🔥 ТЕКУЩИЙ ИСТОЧНИК (GALLERY / CAMERA / FILES)
  String _selectedSource = 'gallery';

  // 🔥 ФОТО С КАМЕРЫ
  File? _cameraImage;
  bool _isCameraMode = false;

  // 🔥 ФАЙЛЫ ИЗ ФАЙЛОВОГО МЕНЕДЖЕРА
  List<File> _selectedFiles = [];
  bool _isFilePickerMode = false;

  @override
  void initState() {
    super.initState();
    print('📱 UploadScreen initialized');
    _requestPermission();
  }

  @override
  void dispose() {
    _photoCache.clear();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    print('🔐 Requesting permission...');
    setState(() {
      _isLoadingPermission = true;
      _permissionError = '';
    });
    
    try {
      final PermissionState permission = await PhotoManager.requestPermissionExtend();
      print('📊 Permission result: ${permission.toString()}');
      
      if (permission == PermissionState.authorized) {
        print('✅ Permission granted');
        setState(() {
          _hasPermission = true;
          _isLoadingPermission = false;
        });
        _loadAlbums();
      } else if (permission == PermissionState.limited) {
        print('⚠️ Limited permission granted');
        setState(() {
          _hasPermission = true;
          _isLoadingPermission = false;
        });
        _loadAlbums();
      } else {
        print('❌ Permission denied');
        setState(() {
          _hasPermission = false;
          _isLoadingPermission = false;
          _permissionError = 'Permission denied. Please try again.';
        });
        _showPermissionDialog();
      }
    } catch (e) {
      print('❌ Error requesting permission: $e');
      setState(() {
        _isLoadingPermission = false;
        _permissionError = 'Error: $e';
      });
      _showErrorDialog('Error requesting permission: $e');
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Photos Access Needed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To select photos for your post, please grant access to your photos.',
              style: TextStyle(color: Colors.white70),
            ),
            if (_permissionError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Error: $_permissionError',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _requestPermission();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAlbums() async {
    print('📁 Loading albums...');
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );
      
      print('📊 Found ${albums.length} albums');
      for (var album in albums) {
        final count = await album.assetCountAsync;
        print('   - ${album.name} ($count photos)');
      }
      
      setState(() {
        _albums.clear();
        _albums.addAll(albums);
        if (_albums.isNotEmpty) {
          _selectedAlbum = _albums.isNotEmpty ? _albums.first : null;
          _selectedFolder = _selectedAlbum?.name ?? 'Recents';
          _loadPhotos();
        } else {
          print('⚠️ No albums found');
        }
      });
    } catch (e) {
      print('❌ Error loading albums: $e');
      _showErrorDialog('Failed to load albums: $e');
    }
  }

  Future<void> _loadPhotos({bool refresh = false}) async {
    if (_selectedAlbum == null) {
      print('⚠️ No album selected');
      return;
    }
    
    if (refresh) {
      print('🔄 Refreshing photos...');
      _currentPage = 0;
      _hasMore = true;
      _photos.clear();
      _selectedAssets.clear();
      _selectedAssetsOrder.clear();
      _photoCache.clear();
    }
    
    if (_isLoading || !_hasMore) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('📸 Loading photos page $_currentPage from ${_selectedAlbum!.name}');
      final photos = await _selectedAlbum!.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );
      
      print('📊 Loaded ${photos.length} photos');
      
      setState(() {
        if (photos.isNotEmpty) {
          _photos.addAll(photos);
          _currentPage++;
          _hasMore = photos.length == _pageSize;
        } else {
          _hasMore = false;
        }
        _isLoading = false;
      });
      
      _preloadPhotos(photos);
    } catch (e) {
      print('❌ Error loading photos: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to load photos: $e');
    }
  }

  Future<void> _preloadPhotos(List<AssetEntity> photos) async {
    for (var asset in photos) {
      if (!_photoCache.containsKey(asset)) {
        final file = await asset.file;
        _photoCache[asset] = file;
      }
    }
  }

  IconData _getAlbumIcon(AssetPathEntity album) {
    final name = album.name.toLowerCase();
    if (name.contains('screenshot')) return Icons.screenshot;
    if (name.contains('camera')) return Icons.camera_alt;
    if (name.contains('whatsapp')) return Icons.message;
    if (name.contains('instagram')) return Icons.photo_camera;
    if (name.contains('download')) return Icons.download;
    if (name.contains('favorite')) return Icons.favorite;
    return Icons.photo_library;
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.containsKey(asset)) {
        _selectedAssets.remove(asset);
        _selectedAssetsOrder.remove(asset);
        
        final updatedMap = <AssetEntity, int>{};
        var index = 1;
        for (var key in _selectedAssetsOrder) {
          updatedMap[key] = index++;
        }
        _selectedAssets.clear();
        _selectedAssets.addAll(updatedMap);
      } else {
        final newNumber = _selectedAssets.length + 1;
        _selectedAssets[asset] = newNumber;
        _selectedAssetsOrder.add(asset);
      }
    });
  }

  Future<File?> _getCachedFile(AssetEntity asset) async {
    if (_photoCache.containsKey(asset)) {
      return _photoCache[asset];
    }
    final file = await asset.file;
    _photoCache[asset] = file;
    return file;
  }

  int? _getSelectedNumber(AssetEntity asset) {
    return _selectedAssets[asset];
  }

  void _changeSource(String source) {
    setState(() {
      _selectedSource = source;
    });
    
    if (source == 'camera') {
      _openCamera();
    } else if (source == 'files') {
      _openFilePicker();
    } else if (source == 'gallery') {
      setState(() {
        _isCameraMode = false;
        _cameraImage = null;
        _isFilePickerMode = false;
        _selectedFiles.clear();
      });
    }
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required String source,
  }) {
    final isSelected = _selectedSource == source;
    
    return GestureDetector(
      onTap: () => _changeSource(source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          _cameraImage = File(file.path);
          _isCameraMode = true;
          _isFilePickerMode = false;
          _selectedFiles.clear();
          _selectedAssets.clear();
          _selectedAssetsOrder.clear();
        });
        
        print('📸 Photo taken: ${file.path}');
      } else {
        setState(() {
          _selectedSource = 'gallery';
          _isCameraMode = false;
        });
      }
    } catch (e) {
      print('❌ Camera error: $e');
      setState(() {
        _selectedSource = 'gallery';
        _isCameraMode = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to take photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openFilePicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.paths.map((path) => File(path!)).toList();
          _isFilePickerMode = true;
          _isCameraMode = false;
          _cameraImage = null;
          _selectedAssets.clear();
          _selectedAssetsOrder.clear();
        });
        
        print('📁 Selected ${result.files.length} files:');
        for (var file in result.files) {
          print('   - ${file.name} (${file.size} bytes)');
        }
      } else {
        setState(() {
          _selectedSource = 'gallery';
          _isFilePickerMode = false;
        });
      }
    } catch (e) {
      print('❌ File picker error: $e');
      setState(() {
        _selectedSource = 'gallery';
        _isFilePickerMode = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _resetFiles() {
    setState(() {
      _selectedFiles.clear();
      _isFilePickerMode = false;
      _selectedSource = 'gallery';
    });
  }

  void _navigateToPreviewFromGallery() {
    List<File> selectedFiles = [];
    
    for (var asset in _selectedAssetsOrder) {
      final file = _photoCache[asset];
      if (file != null) {
        selectedFiles.add(file);
      }
    }
    
    if (selectedFiles.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: selectedFiles,
            selectedAssets: _selectedAssetsOrder,
          ),
        ),
      ).then((_) {
        setState(() {
          _selectedAssets.clear();
          _selectedAssetsOrder.clear();
        });
      });
    }
  }

  void _navigateToPreviewFromCamera() {
    if (_cameraImage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: [_cameraImage!],
          ),
        ),
      ).then((_) {
        setState(() {
          _isCameraMode = false;
          _cameraImage = null;
          _selectedSource = 'gallery';
        });
      });
    }
  }

  void _navigateToPreviewFromFiles() {
    if (_selectedFiles.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: _selectedFiles,
          ),
        ),
      ).then((_) {
        _resetFiles();
      });
    }
  }

  List<String> _extractHashtags(String text) {
    if (text.isEmpty) return [];
    final RegExp regExp = RegExp(r'#(\w+)');
    final matches = regExp.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Checking permissions...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: Colors.grey[600],
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Photos Access Needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To create a post, we need access to your photos.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_permissionError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _permissionError,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Grant Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isCameraMode && _cameraImage != null) {
      return _buildCameraMode();
    }

    if (_isFilePickerMode && _selectedFiles.isNotEmpty) {
      return _buildFilePickerMode();
    }

    return _buildGalleryMode();
  }

  Widget _buildCameraMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isCameraMode = false;
                        _cameraImage = null;
                        _selectedSource = 'gallery';
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  ),
                  const Text(
                    'Camera Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _navigateToPreviewFromCamera,
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _cameraImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Another'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _resetFiles,
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  ),
                  const Text(
                    'Selected Files',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedFiles.isNotEmpty
                        ? _navigateToPreviewFromFiles
                        : null,
                    child: Text(
                      _selectedFiles.isNotEmpty
                          ? 'Next (${_selectedFiles.length})'
                          : 'Next',
                      style: TextStyle(
                        color: _selectedFiles.isNotEmpty
                            ? Colors.white
                            : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _selectedFiles.isNotEmpty
                    ? Image.file(
                        _selectedFiles.first,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 50,
                        ),
                      ),
              ),
            ),

            Expanded(
              child: Container(
                color: Colors.black,
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    final fileNumber = index + 1;
                    
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$fileNumber',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _openFilePicker,
                icon: const Icon(Icons.add),
                label: const Text('Add More Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  ),
                  
                  const Expanded(
                    child: Center(
                      child: Text(
                        'New Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  TextButton(
                    onPressed: _selectedAssets.isNotEmpty
                        ? _navigateToPreviewFromGallery
                        : null,
                    child: Text(
                      _selectedAssets.isNotEmpty
                          ? 'Next (${_selectedAssets.length})'
                          : 'Next',
                      style: TextStyle(
                        color: _selectedAssets.isNotEmpty
                            ? Colors.white
                            : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _selectedAssets.isNotEmpty
                    ? FutureBuilder<File?>(
                        // ✅ ИСПРАВЛЕНО: безопасный .last
                        future: _selectedAssetsOrder.isNotEmpty 
                            ? _getCachedFile(_selectedAssetsOrder.last) 
                            : null,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.grey,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 280,
                              ),
                            );
                          }
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 50,
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              color: Colors.grey,
                              size: 50,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select photos',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            if (_albums.isNotEmpty)
              Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRecentsExpanded = !_isRecentsExpanded;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedFolder,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _isRecentsExpanded 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isRecentsExpanded)
                    Container(
                      width: double.infinity,
                      color: Colors.grey[900],
                      child: Column(
                        children: _albums.map((album) {
                          final isSelected = album == _selectedAlbum;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAlbum = album;
                                _selectedFolder = album.name;
                                _isRecentsExpanded = false;
                                _photos.clear();
                                _selectedAssets.clear();
                                _selectedAssetsOrder.clear();
                                _photoCache.clear();
                                _currentPage = 0;
                                _hasMore = true;
                              });
                              _loadPhotos(refresh: true);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getAlbumIcon(album),
                                    color: isSelected ? Colors.white : Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      album.name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.grey,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const Spacer(),
                                    Icon(
                                      Icons.check,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),

            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSourceButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    source: 'gallery',
                  ),
                  _buildSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    source: 'camera',
                  ),
                  _buildSourceButton(
                    icon: Icons.insert_drive_file,
                    label: 'Files',
                    source: 'files',
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(2),
                child: _photos.isEmpty
                    ? const Center(
                        child: Text(
                          'No photos',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200 &&
                              !_isLoading &&
                              _hasMore) {
                            _loadPhotos();
                          }
                          return false;
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                          itemCount: _photos.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _photos.length) {
                              return Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.grey,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            
                            final asset = _photos[index];
                            final selectedNumber = _getSelectedNumber(asset);
                            
                            return FutureBuilder<File?>(
                              future: _getCachedFile(asset),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                                  return Container(
                                    color: Colors.grey[900],
                                  );
                                }
                                
                                return GestureDetector(
                                  onTap: () => _toggleSelection(asset),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (snapshot.hasData && snapshot.data != null)
                                        Image.file(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        )
                                      else
                                        Container(
                                          color: Colors.grey[900],
                                          child: const Center(
                                            child: Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      
                                      if (selectedNumber != null)
                                        Container(
                                          color: Colors.black.withOpacity(0.4),
                                        ),
                                      
                                      if (selectedNumber != null)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.8),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '$selectedNumber',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
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