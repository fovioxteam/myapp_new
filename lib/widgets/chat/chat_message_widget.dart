import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageWidget extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool isGroup;
  final String? senderName;
  final Function(String)? onLongPress;
  final VoidCallback? onAvatarTap;
  final bool isSelected;
  final Function(String)? onReplyTap;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.isGroup,
    this.senderName,
    this.onLongPress,
    this.onAvatarTap,
    this.isSelected = false,
    this.onReplyTap,
  });

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else {
      return DateFormat('dd.MM.yy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTime(message['createdAt'] ?? message['timestamp']);
    final isEdited = message['edited'] == true;
    final messageType = message['type'] ?? 'text';
    final replyTo = message['replyTo'] as Map<String, dynamic>?;
    
    return GestureDetector(
      onLongPress: () => onLongPress?.call(message['id']),
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 50 : 8,
          right: isMe ? 8 : 50,
        ),
        // 🔥 УБИРАЕМ ЛЮБЫЕ ИЗМЕНЕНИЯ ПРИ ВЫДЕЛЕНИИ
        // Вообще никакого выделения в этом виджете
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && isGroup) ...[
              GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 18, // 🔥 УВЕЛИЧЕНО с 16 до 18
                  backgroundImage: message['senderAvatar'] != null
                      ? CachedNetworkImageProvider(message['senderAvatar'])
                      : null,
                  child: message['senderAvatar'] == null
                      ? const Icon(Icons.person, size: 18) // 🔥 УВЕЛИЧЕНО с 16 до 18
                      : null,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14), // 🔥 УВЕЛИЧЕНО с 12 до 14
                decoration: BoxDecoration(
                  color: isMe ? Colors.black : Colors.grey[100],
                  borderRadius: BorderRadius.circular(18).copyWith( // 🔥 УВЕЛИЧЕНО с 16 до 18
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && isGroup && senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          senderName!,
                          style: TextStyle(
                            fontSize: 14, // 🔥 УВЕЛИЧЕНО с 12 до 14 (как в Telegram)
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    
                    if (replyTo != null)
                      GestureDetector(
                        onTap: () => onReplyTap?.call(replyTo['id']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe 
                                ? Colors.white.withOpacity(0.1) 
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isMe 
                                  ? Colors.white.withOpacity(0.2) 
                                  : Colors.grey[300]!,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply_outlined,
                                size: 14,
                                color: isMe 
                                    ? Colors.white.withOpacity(0.5) 
                                    : Colors.grey[500],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyTo['senderName'] ?? 'User',
                                      style: TextStyle(
                                        fontSize: 12, // Оставляем 12 (как в Telegram)
                                        fontWeight: FontWeight.w500,
                                        color: isMe 
                                            ? Colors.white.withOpacity(0.7) 
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      replyTo['text'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13, // Оставляем 13 (как в Telegram)
                                        color: isMe 
                                            ? Colors.white.withOpacity(0.9) 
                                            : Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: isMe 
                                    ? Colors.white.withOpacity(0.3) 
                                    : Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (messageType == 'image' && message['imageUrl'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isMe 
                                ? Colors.white.withOpacity(0.2) 
                                : Colors.grey[300]!,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: message['imageUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    if (messageType == 'text' && message['text'] != null)
                      Text(
                        message['text'] ?? '',
                        style: TextStyle(
                          fontSize: 16, // 🔥 УВЕЛИЧЕНО с 14 до 16 (как в Telegram!)
                          fontWeight: FontWeight.w400, // 🔥 Обычный вес (не жирный)
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    
                    if (timeString.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6), // 🔥 УВЕЛИЧЕНО с 4 до 6
                        child: Text(
                          timeString + (isEdited ? ' • edited' : ''),
                          style: TextStyle(
                            fontSize: 11, // 🔥 УВЕЛИЧЕНО с 10 до 11 (как в Telegram)
                            color: isMe ? Colors.white70 : Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}