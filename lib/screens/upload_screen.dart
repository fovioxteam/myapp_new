// lib/screens/upload_screen.dart

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

import 'post_preview_screen.dart';
import '../models/media_types.dart';
import '../controllers/post_controller.dart';
import '../extensions/safe_extensions.dart';
import '../utils/video_compressor.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostController _postController = Get.find<PostController>();
  
  String _selectedFolder = 'Recents';
  final List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  
  final Map<String, int> _selectedAssets = {};
  final List<String> _selectedAssetsOrder = [];
  final List<AssetEntity> _mediaItems = [];
  
  int _currentPage = 0;
  final int _pageSize = 40;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRecentsExpanded = false;
  
  bool _hasPermission = false;
  bool _isLoadingPermission = true;
  String _permissionError = '';
  
  final Map<String, Uint8List?> _thumbnailCache = {};
  final Map<String, Duration?> _durationCache = {};
  final Set<String> _loadingAssets = {};
  static const int _maxCacheSize = 80;
  
  Timer? _selectionTimer;
  String _selectedSource = 'gallery';
  
  File? _cameraImage;
  bool _isCameraMode = false;
  List<File> _selectedFiles = [];
  bool _isFilePickerMode = false;

  MediaUploadType _detectedMediaType = MediaUploadType.image;

  @override
  void initState() {
    super.initState();
    print('📱 UploadScreen initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestPermission();
      }
    });
  }

  @override
  void dispose() {
    _selectionTimer?.cancel();
    _thumbnailCache.clear();
    _durationCache.clear();
    _loadingAssets.clear();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    print('🔐 Requesting permission...');
    if (!mounted) return;
    
    setState(() {
      _isLoadingPermission = true;
      _permissionError = '';
    });
    
    try {
      final PermissionState permission = await PhotoManager.requestPermissionExtend();
      print('📊 Permission result: ${permission.toString()}');
      
      if (permission == PermissionState.authorized || permission == PermissionState.limited) {
        print('✅ Permission granted');
        if (mounted) {
          setState(() {
            _hasPermission = true;
            _isLoadingPermission = false;
          });
          _loadAlbums();
        }
      } else {
        print('❌ Permission denied');
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _isLoadingPermission = false;
            _permissionError = 'Permission denied';
          });
          _showPermissionDialog();
        }
      }
    } catch (e) {
      print('❌ Error requesting permission: $e');
      if (mounted) {
        setState(() {
          _isLoadingPermission = false;
          _permissionError = 'Error: $e';
        });
        _showErrorDialog('Permission error. Please try again.');
      }
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
        content: const Text(
          'Please grant access to your photos to create a post.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
        title: const Text('Error', style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadAlbums() async {
    print('📁 Loading albums...');
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          imageOption: FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
          videoOption: FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
            durationConstraint: DurationConstraint(
              max: const Duration(seconds: 60),
            ),
          ),
        ),
      );
      
      print('📊 Found ${albums.length} albums');
      
      if (!mounted) return;
      
      setState(() {
        _albums.clear();
        _albums.addAll(albums);
        if (_albums.isNotEmpty) {
          _selectedAlbum = _albums.first;
          _selectedFolder = _selectedAlbum?.name ?? 'Recents';
        }
      });
      
      if (_selectedAlbum != null) {
        await _loadMedia(refresh: true);
      }
    } catch (e) {
      print('❌ Error loading albums: $e');
      if (mounted) {
        _showErrorDialog('Failed to load albums: $e');
      }
    }
  }

  Future<void> _loadMedia({bool refresh = false}) async {
    if (_selectedAlbum == null) return;
    if (_isLoadingMore) return;
    
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      _mediaItems.clear();
      _selectedAssets.clear();
      _selectedAssetsOrder.clear();
      _thumbnailCache.clear();
      _durationCache.clear();
      _loadingAssets.clear();
    }
    
    if (!_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final media = await _selectedAlbum!.getAssetListPaged(
        page: _currentPage,
        size: _pageSize,
      );
      
      if (!mounted) return;
      
      setState(() {
        if (media.isNotEmpty) {
          _mediaItems.addAll(media);
          _currentPage++;
          _hasMore = media.length == _pageSize;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
      
      _preloadThumbnails(media.take(10).toList());
    } catch (e) {
      print('❌ Error loading media: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _preloadThumbnails(List<AssetEntity> media) async {
    for (var asset in media) {
      if (!_thumbnailCache.containsKey(asset.id) && !_loadingAssets.contains(asset.id)) {
        _loadingAssets.add(asset.id);
        
        final thumbnail = await asset.thumbnailDataWithSize(
          const ThumbnailSize(200, 200),
        );
        
        _loadingAssets.remove(asset.id);
        
        if (mounted && thumbnail != null) {
          setState(() {
            if (_thumbnailCache.length > _maxCacheSize) {
              final oldestKey = _thumbnailCache.keys.first;
              _thumbnailCache.remove(oldestKey);
            }
            _thumbnailCache[asset.id] = thumbnail;
          });
        }
      }
    }
  }

  Future<Uint8List?> _getVideoThumbnail(AssetEntity asset) async {
    if (_thumbnailCache.containsKey(asset.id)) {
      return _thumbnailCache[asset.id];
    }
    
    if (_loadingAssets.contains(asset.id)) {
      return null;
    }
    
    _loadingAssets.add(asset.id);
    
    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(200, 200),
      );
      
      _loadingAssets.remove(asset.id);
      
      if (thumbnail != null) {
        setState(() {
          if (_thumbnailCache.length > _maxCacheSize) {
            final oldestKey = _thumbnailCache.keys.first;
            _thumbnailCache.remove(oldestKey);
          }
          _thumbnailCache[asset.id] = thumbnail;
        });
        return thumbnail;
      }
      return null;
    } catch (e) {
      _loadingAssets.remove(asset.id);
      print('❌ Thumbnail error: $e');
      return null;
    }
  }

  // ============================================================
  // 🔥 ПОЛУЧЕНИЕ ДЛИТЕЛЬНОСТИ ВИДЕО ЧЕРЕЗ VideoCompressor
  // ============================================================
  Future<Duration?> _getVideoDurationForAsset(AssetEntity asset) async {
    if (asset.type != AssetType.video) return null;
    
    final assetId = asset.id;
    
    if (_durationCache.containsKey(assetId)) {
      return _durationCache[assetId];
    }
    
    try {
      final file = await asset.file;
      if (file != null) {
        print('🎬 [DURATION] Getting duration for: ${file.path}');
        
        // 🔥 ИСПОЛЬЗУЕМ НОВЫЙ VideoCompressor
        final durationMs = await VideoCompressor.getVideoDurationMs(file.path);
        if (durationMs > 0) {
          final duration = Duration(milliseconds: durationMs);
          _durationCache[assetId] = duration;
          print('🎬 [DURATION] Duration: ${duration.inSeconds} sec');
          return duration;
        }
      }
    } catch (e) {
      print('❌ [DURATION] Error: $e');
    }
    
    print('⚠️ [DURATION] Could not get duration, showing 0:00');
    _durationCache[assetId] = Duration.zero;
    return Duration.zero;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<File?> _getFileForAsset(AssetEntity asset) async {
    if (asset.type == AssetType.video) {
      return await asset.file;
    }
    return await asset.file;
  }

  void _toggleSelection(AssetEntity asset) async {
    _selectionTimer?.cancel();
    
    if (asset.type == AssetType.video) {
      print('🎬 [UPLOAD] ========== VIDEO SELECTED ==========');
      print('🎬 [UPLOAD] Asset ID: ${asset.id}');
      print('🎬 [UPLOAD] Asset duration: ${asset.duration} seconds');
      print('🎬 [UPLOAD] Asset width: ${asset.width}, height: ${asset.height}');
      
      final file = await _getFileForAsset(asset);
      if (file != null && mounted) {
        final originalSize = await file.length();
        print('🎬 [UPLOAD] Original file size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black,
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Processing video...',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimizing for upload',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
        );
        
        // 🔥 ИСПОЛЬЗУЕМ НОВЫЙ VideoCompressor.compressVideo
        final compressedFile = await VideoCompressor.compressVideo(file.path);
        
        if (mounted) Navigator.pop(context);
        
        if (compressedFile != null) {
          final compressedSize = await compressedFile.length();
          print('🎬 [UPLOAD] Compressed file size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostPreviewScreen(
                  selectedFiles: [compressedFile],
                  selectedAssets: [],
                  mediaType: MediaUploadType.video,
                ),
              ),
            ).then((_) {
              if (mounted) {
                setState(() {
                  _selectedAssets.clear();
                  _selectedAssetsOrder.clear();
                });
              }
            });
          }
        } else {
          // Если сжатие не удалось — используем оригинал
          print('⚠️ [UPLOAD] Compression failed, using original');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostPreviewScreen(
                  selectedFiles: [file],
                  selectedAssets: [],
                  mediaType: MediaUploadType.video,
                ),
              ),
            ).then((_) {
              if (mounted) {
                setState(() {
                  _selectedAssets.clear();
                  _selectedAssetsOrder.clear();
                });
              }
            });
          }
        }
      }
      return;
    }
    
    _selectionTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      
      setState(() {
        if (_selectedAssets.containsKey(asset.id)) {
          _selectedAssets.remove(asset.id);
          _selectedAssetsOrder.remove(asset.id);
          
          final updatedMap = <String, int>{};
          var index = 1;
          for (var id in _selectedAssetsOrder) {
            updatedMap[id] = index++;
          }
          _selectedAssets.clear();
          _selectedAssets.addAll(updatedMap);
        } else {
          final newNumber = _selectedAssets.length + 1;
          _selectedAssets[asset.id] = newNumber;
          _selectedAssetsOrder.add(asset.id);
        }
      });
    });
  }

  int? _getSelectedNumber(AssetEntity asset) {
    return _selectedAssets[asset.id];
  }

  void _changeSource(String source) {
    setState(() {
      _selectedSource = source;
    });
    
    if (source == 'camera') {
      _checkAndOpenCamera();
    } else if (source == 'files') {
      _openFilePicker();
    } else if (source == 'gallery') {
      setState(() {
        _isCameraMode = false;
        _cameraImage = null;
        _isFilePickerMode = false;
        _selectedFiles.clear();
        _detectedMediaType = MediaUploadType.image;
      });
    }
  }

  Future<void> _checkAndOpenCamera() async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      await _openCamera();
    } else if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        await _openCamera();
      } else {
        _showCameraPermissionDialog();
        setState(() {
          _selectedSource = 'gallery';
        });
      }
    } else if (status.isPermanentlyDenied) {
      _showCameraPermissionDialog();
      setState(() {
        _selectedSource = 'gallery';
      });
    }
  }

  Future<void> _openCamera() async {
    try {
      final choice = await showDialog<MediaUploadType>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Choose Media Type',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text('Photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, MediaUploadType.image),
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white),
                title: const Text('Video', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, MediaUploadType.video),
              ),
            ],
          ),
        ),
      );
      
      if (choice == null) {
        setState(() {
          _selectedSource = 'gallery';
        });
        return;
      }
      
      final picker = ImagePicker();
      
      if (choice == MediaUploadType.video) {
        final video = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 60),
        );
        
        if (video != null && mounted) {
          final file = File(video.path);
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Processing video...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
          
          // 🔥 ИСПОЛЬЗУЕМ НОВЫЙ VideoCompressor
          final compressedFile = await VideoCompressor.compressVideo(file.path);
          if (mounted) Navigator.pop(context);
          
          if (compressedFile != null) {
            setState(() {
              _selectedFiles = [compressedFile];
              _detectedMediaType = MediaUploadType.video;
              _selectedAssets.clear();
              _selectedAssetsOrder.clear();
            });
            _navigateToPreview();
          } else {
            setState(() {
              _selectedFiles = [file];
              _detectedMediaType = MediaUploadType.video;
              _selectedAssets.clear();
              _selectedAssetsOrder.clear();
            });
            _navigateToPreview();
          }
        }
      } else {
        final file = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        
        if (file != null && mounted) {
          setState(() {
            _cameraImage = File(file.path);
            _isCameraMode = true;
            _isFilePickerMode = false;
            _selectedFiles.clear();
            _selectedAssets.clear();
            _selectedAssetsOrder.clear();
            _detectedMediaType = MediaUploadType.image;
          });
        }
      }
    } catch (e) {
      print('❌ Camera error: $e');
      if (mounted) {
        setState(() {
          _selectedSource = 'gallery';
        });
        _showSnackBar('Could not open camera. Please check permissions.', Colors.red);
      }
    }
  }

  void _showCameraPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Text('Camera Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Camera access is needed to take photos for your post.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              final permission = await Permission.camera.status;
              if (permission.isGranted) {
                await _openCamera();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilePicker() async {
    try {
      final choice = await showDialog<MediaUploadType>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Choose File Type',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.white),
                title: const Text('Images', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, MediaUploadType.image),
              ),
              ListTile(
                leading: const Icon(Icons.video_file, color: Colors.white),
                title: const Text('Videos', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, MediaUploadType.video),
              ),
            ],
          ),
        ),
      );
      
      if (choice == null) {
        setState(() {
          _selectedSource = 'gallery';
        });
        return;
      }
      
      FilePickerResult? result;
      
      if (choice == MediaUploadType.video) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
        
        if (result != null && result.files.isNotEmpty && mounted) {
          final file = File(result.files.first.path!);
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Processing video...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
          
          // 🔥 ИСПОЛЬЗУЕМ НОВЫЙ VideoCompressor
          final compressedFile = await VideoCompressor.compressVideo(file.path);
          if (mounted) Navigator.pop(context);
          
          if (compressedFile != null) {
            setState(() {
              _selectedFiles = [compressedFile];
              _detectedMediaType = MediaUploadType.video;
              _isFilePickerMode = true;
              _isCameraMode = false;
              _cameraImage = null;
              _selectedAssets.clear();
              _selectedAssetsOrder.clear();
            });
            _navigateToPreview();
          } else {
            setState(() {
              _selectedFiles = [file];
              _detectedMediaType = MediaUploadType.video;
              _isFilePickerMode = true;
              _isCameraMode = false;
              _cameraImage = null;
              _selectedAssets.clear();
              _selectedAssetsOrder.clear();
            });
            _navigateToPreview();
          }
        }
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        
        if (result != null && result.files.isNotEmpty && mounted) {
          final paths = result.paths.where((p) => p != null).cast<String>().toList();
          setState(() {
            _selectedFiles = paths.map((path) => File(path)).toList();
            _isFilePickerMode = true;
            _isCameraMode = false;
            _cameraImage = null;
            _selectedAssets.clear();
            _selectedAssetsOrder.clear();
            _detectedMediaType = MediaUploadType.image;
          });
        }
      }
      
      if (result != null) {
        print('📁 Selected ${result.files.length} files');
      } else if (mounted) {
        setState(() {
          _selectedSource = 'gallery';
          _isFilePickerMode = false;
        });
      }
    } catch (e) {
      print('❌ File picker error: $e');
      if (mounted) {
        setState(() {
          _selectedSource = 'gallery';
          _isFilePickerMode = false;
        });
        _showSnackBar('Failed to pick files: $e', Colors.red);
      }
    }
  }

  void _resetFiles() {
    setState(() {
      _selectedFiles.clear();
      _isFilePickerMode = false;
      _selectedSource = 'gallery';
      _detectedMediaType = MediaUploadType.image;
    });
  }

  void _navigateToPreview() {
    if (_selectedFiles.isEmpty) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPreviewScreen(
          selectedFiles: _selectedFiles,
          selectedAssets: [],
          mediaType: _detectedMediaType,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedAssets.clear();
          _selectedAssetsOrder.clear();
          _selectedFiles.clear();
          _detectedMediaType = MediaUploadType.image;
        });
      }
    });
  }

  void _navigateToPreviewFromGallery() async {
    List<File> selectedFiles = [];
    
    for (var assetId in _selectedAssetsOrder) {
      final asset = _mediaItems.firstWhere(
        (a) => a.id == assetId,
        orElse: () => throw Exception('Asset not found'),
      );
      final file = await _getFileForAsset(asset);
      if (file != null) {
        selectedFiles.add(file);
      }
    }
    
    if (selectedFiles.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: selectedFiles,
            selectedAssets: [],
            mediaType: MediaUploadType.image,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _selectedAssets.clear();
            _selectedAssetsOrder.clear();
          });
        }
      });
    }
  }

  void _navigateToPreviewFromCamera() {
    if (_cameraImage != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: [_cameraImage!],
            selectedAssets: [],
            mediaType: MediaUploadType.image,
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isCameraMode = false;
            _cameraImage = null;
            _selectedSource = 'gallery';
          });
        }
      });
    }
  }

  void _navigateToPreviewFromFiles() {
    if (_selectedFiles.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostPreviewScreen(
            selectedFiles: _selectedFiles,
            selectedAssets: [],
            mediaType: _detectedMediaType,
          ),
        ),
      ).then((_) {
        _resetFiles();
      });
    }
  }

  Widget _buildGalleryMode() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
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
                      child: Text('New Post', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedAssets.isNotEmpty ? _navigateToPreviewFromGallery : null,
                    child: Text(
                      _selectedAssets.isNotEmpty ? 'Next (${_selectedAssets.length})' : 'Next',
                      style: TextStyle(
                        color: _selectedAssets.isNotEmpty ? Colors.white : Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Preview area
            Container(
              height: 280,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: _selectedAssets.isNotEmpty && _selectedAssetsOrder.isNotEmpty
                    ? FutureBuilder<File?>(
                        future: _getFileForAsset(
                          _mediaItems.firstWhere(
                            (a) => a.id == _selectedAssetsOrder.last,
                            orElse: () => throw Exception('Asset not found'),
                          ),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                            return const Center(child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 2));
                          }
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(snapshot.data!, fit: BoxFit.cover, width: double.infinity, height: 280),
                            );
                          }
                          return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50));
                        },
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined, color: Colors.grey, size: 50),
                            SizedBox(height: 8),
                            Text('Select photos', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ],
                        ),
                      ),
              ),
            ),

            // Albums
            if (_albums.isNotEmpty)
              Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isRecentsExpanded = !_isRecentsExpanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(_selectedFolder, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Icon(_isRecentsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey, size: 24),
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
                              });
                              _loadMedia(refresh: true);
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(_getAlbumIcon(album), color: isSelected ? Colors.white : Colors.grey, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(album.name, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 16), overflow: TextOverflow.ellipsis),
                                  ),
                                  if (isSelected) ...[
                                    const Spacer(),
                                    Icon(Icons.check, color: Colors.grey, size: 18),
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

            // Bottom buttons
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSourceButton(icon: Icons.photo_library, label: 'Gallery', source: 'gallery'),
                  _buildSourceButton(icon: Icons.camera_alt, label: 'Camera', source: 'camera'),
                  _buildSourceButton(icon: Icons.insert_drive_file, label: 'Files', source: 'files'),
                ],
              ),
            ),

            // ============================================================
            // 🔥 ГРИД - ОРИГИНАЛЬНЫЙ ДИЗАЙН ВЫБОРА
            // ============================================================
            Expanded(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.all(2),
                child: _mediaItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text('No media found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200 &&
                              !_isLoadingMore &&
                              _hasMore) {
                            _loadMedia();
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
                          itemCount: _mediaItems.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _mediaItems.length && _isLoadingMore) {
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
                            
                            final asset = _mediaItems[index];
                            final selectedNumber = _getSelectedNumber(asset);
                            final isVideo = asset.type == AssetType.video;
                            
                            return FutureBuilder<Uint8List?>(
                              future: _getVideoThumbnail(asset),
                              builder: (context, thumbSnapshot) {
                                final hasThumbnail = thumbSnapshot.hasData && thumbSnapshot.data != null;
                                
                                return FutureBuilder<Duration?>(
                                  future: _getVideoDurationForAsset(asset),
                                  builder: (context, durationSnapshot) {
                                    final duration = durationSnapshot.data;
                                    
                                    return GestureDetector(
                                      onTap: () => _toggleSelection(asset),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // ТАМБНЕЙЛ
                                          if (hasThumbnail)
                                            Image.memory(
                                              thumbSnapshot.data!,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true,
                                            )
                                          else
                                            Container(
                                              color: Colors.grey[900],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          
                                          // ЗАТЕМНЕНИЕ ПРИ ВЫБОРЕ
                                          if (selectedNumber != null)
                                            Container(color: Colors.black.withOpacity(0.4)),
                                          
                                          // ВРЕМЯ ДЛЯ ВИДЕО (БЕЗ ФОНА)
                                          if (isVideo && duration != null)
                                            Positioned(
                                              bottom: 4,
                                              right: 4,
                                              child: Text(
                                                _formatDuration(duration),
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.9),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black.withOpacity(0.8),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          
                                          // 🔥 НОМЕР ВЫБРАННОГО (ОРИГИНАЛ - ЧЕРНЫЙ КРУГ С БЕЛОЙ ЦИФРОЙ)
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

  IconData _getAlbumIcon(AssetPathEntity album) {
    final name = album.name.toLowerCase();
    if (name.contains('screenshot')) return Icons.screenshot;
    if (name.contains('camera')) return Icons.camera_alt;
    if (name.contains('whatsapp')) return Icons.message;
    if (name.contains('instagram')) return Icons.photo_camera;
    if (name.contains('download')) return Icons.download;
    if (name.contains('favorite')) return Icons.favorite;
    if (name.contains('video')) return Icons.videocam;
    return Icons.photo_library;
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
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
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
              Text('Checking permissions...', style: TextStyle(color: Colors.white)),
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
                  decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle),
                  child: Icon(Icons.photo_library_outlined, color: Colors.grey[600], size: 50),
                ),
                const SizedBox(height: 24),
                const Text('Photos Access Needed', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('To create a post, we need access to your photos.', style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
                if (_permissionError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_permissionError, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Grant Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                  const Text('Camera Photo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: _navigateToPreviewFromCamera,
                    child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(_cameraImage!, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _checkAndOpenCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Another'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
    final isVideo = _detectedMediaType == MediaUploadType.video;
    
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
                  Text(
                    isVideo ? 'Selected Video' : 'Selected Files',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _selectedFiles.isNotEmpty ? _navigateToPreviewFromFiles : null,
                    child: Text(
                      _selectedFiles.isNotEmpty ? 'Next (${_selectedFiles.length})' : 'Next',
                      style: TextStyle(
                        color: _selectedFiles.isNotEmpty ? Colors.white : Colors.grey[600],
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
                    ? isVideo
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_outline, color: Colors.white, size: 60),
                                SizedBox(height: 12),
                                Text('Video Selected', style: TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          )
                        : Image.file(_selectedFiles.first, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 50),
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
                          child: isVideo
                              ? const Center(
                                  child: Icon(Icons.videocam, color: Colors.white, size: 40),
                                )
                              : Image.file(file, fit: BoxFit.cover),
                        ),
                        Container(color: Colors.black.withOpacity(0.3)),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                              child: Text('$fileNumber', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                label: Text(isVideo ? 'Select Another Video' : 'Add More Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}