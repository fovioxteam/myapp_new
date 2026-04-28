import 'package:flutter/material.dart';

void showBottomActionSheet(
  BuildContext context, {
  required VoidCallback onShare,
  required VoidCallback onDownload,
  required VoidCallback onReport,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black.withOpacity(0.95),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(8))),
            ListTile(leading: const Icon(Icons.share, color: Colors.white), title: const Text('Share', style: TextStyle(color: Colors.white)), onTap: onShare),
            ListTile(leading: const Icon(Icons.download, color: Colors.white), title: const Text('Download', style: TextStyle(color: Colors.white)), onTap: onDownload),
            ListTile(leading: const Icon(Icons.flag, color: Colors.redAccent), title: const Text('Report', style: TextStyle(color: Colors.redAccent)), onTap: onReport),
          ],
        ),
      );
    },
  );
}
