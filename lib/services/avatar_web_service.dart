// lib/services/avatar_web_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AvatarWebService {
  static Future<String?> uploadAvatarForWeb() async {
    try {
      print('🚀 Начинаю загрузку аватарки (Web)...');
      
      // 1. Проверяем пользователя
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Пользователь не авторизован');
        return null;
      }
      
      print('👤 Пользователь: ${user.uid}');

      // 2. Выбираем фото
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      
      if (image == null) {
        print('❌ Фото не выбрано');
        return null;
      }
      
      print('📸 Выбрано фото: ${image.name}');

      // 3. Читаем байты (ВАЖНО для Web)
      final bytes = await image.readAsBytes();
      print('📦 Размер файла: ${bytes.length} байт');

      // 4. Создаем путь в Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'avatars/${user.uid}/$timestamp.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      
      print('📤 Загружаю в: $fileName');

      // 5. Загружаем через putData (работает на Web)
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 6. Ждем загрузки
      final snapshot = await uploadTask;
      print('✅ Файл загружен');

      // 7. Получаем URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 URL: $downloadUrl');

      // 8. Сохраняем в Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'avatarUrl': downloadUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      print('💾 Сохранено в Firestore');

      return downloadUrl;

    } catch (e) {
      print('❌ Ошибка загрузки аватарки: $e');
      return null;
    }
  }
}