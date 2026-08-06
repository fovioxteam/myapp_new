import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

class R2Service {
  // 🔥 ТВОИ ДАННЫЕ
  static const String _accountId = 'bf4b2ee360da914b461542296c762597';
  static const String _accessKeyId = '01dae997b47dabdf759771805c4fef99';
  static const String _secretAccessKey = '4b3690b64d869cf3eb553122aea730b99ebff7995276f2a1b106baebc869b57b';
  static const String _bucketName = 'videos';
  
  // 🔥 ПУБЛИЧНЫЙ URL
  static const String _publicUrl = 'https://pub-c30de1e07ea044e1bade4e345636e08d.r2.dev';
  static const String _endpoint = 'https://bf4b2ee360da914b461542296c762597.r2.cloudflarestorage.com';
  
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
      validateStatus: (status) => status! >= 200 && status < 500,
    ),
  );
  
  // ============================================================
  // 🔥 ЗАГРУЗКА ВИДЕО
  // ============================================================
  Future<String> uploadVideo(File videoFile, String userId) async {
    try {
      final fileName = _generateFileName(userId, videoFile);
      final fileSize = await videoFile.length();
      
      print('📤 [R2] ========== UPLOAD START ==========');
      print('📤 [R2] FileName: $fileName');
      print('📤 [R2] FileSize: ${_formatSize(fileSize)}');
      print('📤 [R2] FileSize bytes: $fileSize');
      
      if (fileSize < 1024) {
        print('❌ [R2] File too small! Size: $fileSize bytes');
        throw Exception('Video file is too small (${fileSize} bytes). File might be corrupted.');
      }
      
      final url = '$_endpoint/$_bucketName/$fileName';
      print('📤 [R2] Upload URL: $url');
      
      final bytes = await videoFile.readAsBytes();
      print('📤 [R2] Bytes read: ${bytes.length}');
      
      if (bytes.length > 4) {
        final header = bytes.sublist(0, 4);
        print('📤 [R2] File header bytes: ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
        if (bytes.length > 8) {
          final ftypCheck = bytes.sublist(4, 8);
          final ftypStr = String.fromCharCodes(ftypCheck);
          print('📤 [R2] File type signature: $ftypStr');
        }
      }
      
      final headers = _buildS3Headers(
        method: 'PUT',
        path: '/$_bucketName/$fileName',
        contentType: 'video/mp4',
        contentLength: fileSize,
        body: bytes,
      );
      
      print('📤 [R2] Headers prepared, starting upload...');
      
      final response = await _dio.put(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: headers,
        ),
        onSendProgress: (sent, total) {
          final percent = (sent / total * 100).toStringAsFixed(1);
          print('📤 [R2] Progress: $percent% ($sent / $total bytes)');
        },
      );
      
      print('📤 [R2] Response status: ${response.statusCode}');
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('❌ [R2] Upload failed: ${response.statusCode}');
        print('❌ [R2] Response: ${response.data}');
        throw Exception('Upload failed: ${response.statusCode}');
      }
      
      final publicUrl = '$_publicUrl/$fileName';
      
      print('✅ [R2] Upload success!');
      print('🔗 [R2] URL: $publicUrl');
      print('📤 [R2] ========== UPLOAD END ==========');
      
      return publicUrl;
      
    } catch (e) {
      print('❌ [R2] Upload error: $e');
      throw Exception('Failed to upload video: $e');
    }
  }
  
  // ============================================================
  // 🔥 ЗАГРУЗКА ВИДЕО ИЗ Uint8List
  // ============================================================
  Future<String> uploadVideoBytes(Uint8List bytes, String userId) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final fileSize = bytes.length;
      
      print('📤 [R2] ========== UPLOAD BYTES START ==========');
      print('📤 [R2] FileName: $fileName');
      print('📤 [R2] FileSize: ${_formatSize(fileSize)}');
      
      final url = '$_endpoint/$_bucketName/$fileName';
      
      final headers = _buildS3Headers(
        method: 'PUT',
        path: '/$_bucketName/$fileName',
        contentType: 'video/mp4',
        contentLength: fileSize,
        body: bytes,
      );
      
      final response = await _dio.put(
        url,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: headers,
        ),
        onSendProgress: (sent, total) {
          final percent = (sent / total * 100).toStringAsFixed(1);
          print('📤 [R2] Progress: $percent%');
        },
      );
      
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
      
      final publicUrl = '$_publicUrl/$fileName';
      
      print('✅ [R2] Upload success!');
      print('🔗 [R2] URL: $publicUrl');
      
      return publicUrl;
      
    } catch (e) {
      print('❌ [R2] Upload bytes error: $e');
      rethrow;
    }
  }
  
  // ============================================================
  // 🔥 УДАЛЕНИЕ ФАЙЛА ИЗ R2
  // ============================================================
  Future<void> deleteFile(String fileUrl) async {
    try {
      print('🗑️ [R2] ========== DELETE START ==========');
      print('🗑️ [R2] File URL: $fileUrl');
      
      // Извлекаем путь из URL
      final uri = Uri.parse(fileUrl);
      final pathWithQuery = uri.path;
      
      // Формируем URL для удаления через S3 API
      final deleteUrl = '$_endpoint/$_bucketName$pathWithQuery';
      print('🗑️ [R2] Delete URL: $deleteUrl');
      
      // Создаем заголовки для DELETE запроса
      final headers = _buildS3Headers(
        method: 'DELETE',
        path: '/$_bucketName$pathWithQuery',
        contentType: '',
        contentLength: 0,
        body: [],
      );
      
      final response = await _dio.delete(
        deleteUrl,
        options: Options(
          headers: headers,
        ),
      );
      
      print('🗑️ [R2] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ [R2] File deleted successfully: $fileUrl');
      } else if (response.statusCode == 404) {
        print('⚠️ [R2] File already deleted or not found: $fileUrl');
      } else {
        print('⚠️ [R2] Delete response: ${response.statusCode}');
        print('⚠️ [R2] Response body: ${response.data}');
      }
      
      print('🗑️ [R2] ========== DELETE END ==========');
      
    } catch (e) {
      print('❌ [R2] Delete error: $e');
      // Не пробрасываем ошибку, чтобы удаление из Firestore всё равно прошло
    }
  }
  
  // ============================================================
  // 🔥 ПРОВЕРКА СУЩЕСТВОВАНИЯ ФАЙЛА
  // ============================================================
  Future<bool> fileExists(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final pathWithQuery = uri.path;
      final url = '$_endpoint/$_bucketName$pathWithQuery';
      
      final headers = _buildS3Headers(
        method: 'HEAD',
        path: '/$_bucketName$pathWithQuery',
        contentType: '',
        contentLength: 0,
        body: [],
      );
      
      final response = await _dio.head(
        url,
        options: Options(
          headers: headers,
        ),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // ============================================================
  // 🔥 ПОЛУЧЕНИЕ ПУБЛИЧНОГО URL
  // ============================================================
  Future<String> getVideoUrl(String fileName) async {
    return '$_publicUrl/$fileName';
  }
  
  // ============================================================
  // 🔥 S3 HEADERS (AWS4-HMAC-SHA256)
  // ============================================================
  Map<String, String> _buildS3Headers({
    required String method,
    required String path,
    required String contentType,
    required int contentLength,
    required List<int> body,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final region = 'auto';
    final service = 's3';
    final host = _endpoint.replaceFirst('https://', '');
    
    // Хеш тела (для DELETE и HEAD body пустой)
    final payloadHash = body.isEmpty ? _sha256Empty : _sha256(body);
    
    // Canonical headers
    final canonicalHeaders = 
        'content-type:$contentType\n'
        'host:$host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    
    final signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
    
    // Canonical request
    final canonicalRequest = 
        '$method\n'
        '$path\n'
        '\n'  // query string
        '$canonicalHeaders'
        '\n'
        '$signedHeaders\n'
        '$payloadHash';
    
    // String to sign
    final credentialScope = '$dateStamp/$region/$service/aws4_request';
    final hashedCanonicalRequest = _sha256(utf8.encode(canonicalRequest));
    final stringToSign = 
        'AWS4-HMAC-SHA256\n'
        '$amzDate\n'
        '$credentialScope\n'
        '$hashedCanonicalRequest';
    
    // Signature
    final signature = _sign(stringToSign, _secretAccessKey, dateStamp, region, service);
    
    // Authorization header
    final authorization = 
        'AWS4-HMAC-SHA256 '
        'Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
    
    final headers = {
      'Content-Type': contentType,
      'Host': host,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      'Authorization': authorization,
    };
    
    // Content-Length только для PUT (не для DELETE и HEAD)
    if (method == 'PUT') {
      headers['Content-Length'] = contentLength.toString();
    }
    
    return headers;
  }
  
  // ============================================================
  // 🔥 ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ============================================================
  
  String get _sha256Empty => _sha256(utf8.encode(''));
  
  String _formatAmzDate(DateTime date) {
    return '${date.year}${_pad(date.month)}${_pad(date.day)}T${_pad(date.hour)}${_pad(date.minute)}${_pad(date.second)}Z';
  }
  
  String _formatDateStamp(DateTime date) {
    return '${date.year}${_pad(date.month)}${_pad(date.day)}';
  }
  
  String _pad(int n) => n.toString().padLeft(2, '0');
  
  String _sha256(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }
  
  String _sign(String stringToSign, String secretKey, String dateStamp, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secretKey')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();
  }
  
  String _generateFileName(String userId, File file) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    final extension = path.extension(file.path);
    return '$userId/${timestamp}_$random$extension';
  }
  
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}