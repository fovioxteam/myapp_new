import 'package:flutter/material.dart';
import '../models/post_tag.dart';
import '../utils/link_utils.dart';

class TagEditorWidget extends StatefulWidget {
  final double x;
  final double y;
  final Function(PostTag) onSave;
  final VoidCallback? onCancel;

  const TagEditorWidget({
    super.key,
    required this.x,
    required this.y,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<TagEditorWidget> createState() => _TagEditorWidgetState();
}

class _TagEditorWidgetState extends State<TagEditorWidget> {
  final TextEditingController _urlController = TextEditingController();
  String? _errorText;
  String? _detectedPlatform;
  String? _detectedDisplayName;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String value) {
    setState(() {
      _errorText = null;
      if (value.trim().isNotEmpty && LinkUtils.isValidUrl(value.trim())) {
        _detectedPlatform = LinkUtils.detectPlatform(value.trim());
        _detectedDisplayName = LinkUtils.getDisplayName(
          value.trim(),
          platform: _detectedPlatform,
        );
      } else {
        _detectedPlatform = null;
        _detectedDisplayName = null;
      }
    });
  }

  void _save() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorText = 'Enter a link');
      return;
    }
    if (!LinkUtils.isValidUrl(url)) {
      setState(() => _errorText = 'Invalid link');
      return;
    }
    if (!LinkUtils.isAllowedDomain(url)) {
      setState(() => _errorText = 'Domain not supported');
      return;
    }

    final platform = LinkUtils.detectPlatform(url);
    final displayName = LinkUtils.getDisplayName(url, platform: platform);

    final tag = PostTag(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      x: widget.x,
      y: widget.y,
      url: url,
      platform: platform,
      displayName: displayName,
    );

    widget.onSave(tag);
    Navigator.pop(context);
  }

  void _cancel() {
    widget.onCancel?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // 👈 явно белый фон
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
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
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                onChanged: _onUrlChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Paste link...',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                  prefixIcon: const Icon(Icons.link, color: Colors.black),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _urlController.clear();
                            setState(() {
                              _detectedPlatform = null;
                              _detectedDisplayName = null;
                              _errorText = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18, color: Colors.black),
                        )
                      : null,
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black, width: 1.5),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey, width: 1.0),
                  ),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              if (_detectedDisplayName != null && _errorText == null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        'Detected: $_detectedDisplayName',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  // Кнопка Cancel – прозрачная с черной обводкой
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 1.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25), // 👈 большой радиус
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Кнопка Save – черная с белым текстом
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25), // 👈 большой радиус
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}