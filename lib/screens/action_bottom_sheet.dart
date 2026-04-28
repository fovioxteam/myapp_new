import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ActionBottomSheet extends StatelessWidget {
  final QueryDocumentSnapshot photo;
  const ActionBottomSheet({super.key, required this.photo});

  Future<void> _downloadImage(BuildContext context) async {
    final url = photo['url'] as String;
    try {
      final res = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(res.bodyBytes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скачано во временную папку')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _report(BuildContext context) async {
    await FirebaseFirestore.instance.collection('reports').add({'photoId': photo.id, 'timestamp': FieldValue.serverTimestamp()});
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Жалоба отправлена')));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Column(children: [
        const SizedBox(height: 12),
        Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(8))),
        ListTile(leading: const Icon(Icons.download, color: Colors.white), title: const Text('Скачать', style: TextStyle(color: Colors.white)), onTap: () => _downloadImage(context)),
        ListTile(leading: const Icon(Icons.share, color: Colors.white), title: const Text('Поделиться', style: TextStyle(color: Colors.white)), onTap: () {
          Share.share('${photo['caption'] ?? ''}\n${photo['url']}');
          Navigator.pop(context);
        }),
        ListTile(leading: const Icon(Icons.report, color: Colors.red), title: const Text('Пожаловаться', style: TextStyle(color: Colors.white)), onTap: () => _report(context)),
      ]),
    );
  }
}
