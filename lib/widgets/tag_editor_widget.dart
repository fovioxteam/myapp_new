import 'package:flutter/material.dart';

import '../models/post_tag.dart';
import '../utils/link_utils.dart';

class TagEditorWidget extends StatefulWidget {
  final double x;
  final double y;
  final Function(PostTag) onSave;

  const TagEditorWidget({
    super.key,
    required this.x,
    required this.y,
    required this.onSave,
  });

  @override
  State<TagEditorWidget> createState() => _TagEditorWidgetState();
}

class _TagEditorWidgetState extends State<TagEditorWidget> {
  final TextEditingController _urlController =
      TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _save() {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      return;
    }

    final tag = PostTag(
      x: widget.x,
      y: widget.y,
      url: url,
      platform: LinkUtils.detectPlatform(url),
    );

    widget.onSave(tag);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Link',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'Paste link...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}