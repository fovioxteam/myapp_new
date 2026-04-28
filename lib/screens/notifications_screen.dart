// lib/screens/notifications_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsController controller;
  
  @override
  void initState() {
    super.initState();
    
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
    
    controller = Get.find<NotificationsController>();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  // 🔥 ИСПРАВЛЕННЫЙ МЕТОД _showClearMenu
  void _showClearMenu() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Clear All Notifications',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await controller.clearAllNotifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    _buildStyledSnackBar('All notifications cleared'),
                  );
                }
              },
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  SnackBar _buildStyledSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
  
  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
  
  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notificationDate = DateTime(date.year, date.month, date.day);
    
    if (notificationDate == today) return 'Today';
    if (notificationDate == yesterday) return 'Yesterday';
    
    return DateFormat('MMMM d, yyyy').format(date);
  }
  
  String _getNotificationBody(Map<String, dynamic> notification) {
    final type = notification['type'] ?? '';
    final senderName = notification['senderName']?.toString() ?? 'Someone';
    final commentText = notification['commentText']?.toString() ?? '';
    
    switch (type) {
      case 'like':
        return 'liked your post';
      case 'comment':
        if (commentText.isNotEmpty) {
          return 'commented: "$commentText"';
        }
        return 'commented on your post';
      case 'follow':
        return 'started following you';
      case 'mention':
        if (commentText.isNotEmpty) {
          return 'mentioned you in a comment: "$commentText"';
        }
        return 'mentioned you';
      default:
        return notification['body']?.toString() ?? '';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
          splashRadius: 24,
          constraints: const BoxConstraints(),
        ),
        actions: [
          GetBuilder<NotificationsController>(
            builder: (ctrl) {
              if (ctrl.notifications.isNotEmpty) {
                return IconButton(
                  icon: const Icon(CupertinoIcons.delete, color: Colors.black, size: 22),
                  onPressed: _showClearMenu,
                  tooltip: 'Clear notifications',
                  splashRadius: 24,
                  constraints: const BoxConstraints(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GetBuilder<NotificationsController>(
        builder: (ctrl) {
          if (ctrl.isLoading && ctrl.notifications.isEmpty) {
            return _buildShimmerLoading();
          }
          
          final displayNotifications = ctrl.debouncedSearchQuery.isNotEmpty
              ? ctrl.filteredNotifications
              : ctrl.notifications;
          
          if (displayNotifications.isEmpty) {
            return ctrl.debouncedSearchQuery.isNotEmpty
                ? _buildEmptySearchState()
                : _buildEmptyState();
          }
          
          return CustomScrollView(
            controller: ctrl.scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await ctrl.refreshNotifications();
                },
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == displayNotifications.length) {
                      if (ctrl.isLoadingMore) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CupertinoActivityIndicator(radius: 12),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    
                    final notification = displayNotifications[index];
                    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final showHeader = index == 0 || 
                        _getDateHeader(createdAt) !=
                        _getDateHeader((displayNotifications[index - 1]['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
                    
                    return Column(
                      children: [
                        if (showHeader)
                          _buildDateHeader(createdAt),
                        _buildNotificationItem(notification, ctrl),
                      ],
                    );
                  },
                  childCount: displayNotifications.length + 1,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildDateHeader(DateTime date) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      alignment: Alignment.centerLeft,
      child: Text(
        _getDateHeader(date),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
  
  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      color: Colors.grey.shade200,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // 🔥 ИСПРАВЛЕННЫЙ DismissIBLE
  Widget _buildNotificationItem(Map<String, dynamic> notification, NotificationsController ctrl) {
    final isRead = notification['isRead'] ?? false;
    final senderAvatar = notification['senderAvatar']?.toString() ?? '';
    final senderName = notification['senderName']?.toString() ?? 'User';
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final bodyText = _getNotificationBody(notification);
    
    return Dismissible(
      key: Key(notification['id']),
      dismissThresholds: const {
        DismissDirection.endToStart: 0.3,
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Delete Notification',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: const Text(
                'Are you sure you want to delete this notification?',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        ctrl.deleteNotification(notification['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            _buildStyledSnackBar('Notification deleted'),
          );
        }
      },
      child: Material(
        color: isRead ? Colors.white : Colors.grey.shade50,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification, ctrl),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final senderId = notification['senderId'];
                    if (senderId != null) {
                      Get.to(() => UserProfileScreen(userId: senderId.toString()));
                    }
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: senderAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(senderAvatar) as ImageProvider
                        : null,
                    child: senderAvatar.isEmpty
                        ? Icon(Icons.person, color: Colors.grey.shade400, size: 22)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: senderName,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                color: Colors.black,
                                fontSize: 14,
                              ),
                            ),
                            TextSpan(
                              text: ' $bodyText',
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTimeAgo(createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _handleNotificationTap(Map<String, dynamic> notification, NotificationsController ctrl) async {
    await ctrl.markAsRead(notification['id']);
    
    final type = notification['type'] ?? '';
    final senderId = notification['senderId'];
    final postId = notification['postId'];
    
    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        if (postId != null) {
          _openPostDetail(notification);
        }
        break;
        
      case 'follow':
        if (senderId != null) {
          Get.to(() => UserProfileScreen(
            userId: senderId.toString(),
          ));
        }
        break;
    }
  }
  
  Future<void> _openPostDetail(Map<String, dynamic> notification) async {
    final postId = notification['postId']?.toString();
    if (postId == null) return;
    
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      if (postDoc.exists) {
        final post = postDoc.data()!;
        post['id'] = postDoc.id;
        
        Get.to(() => PostDetailScreen(
          posts: [post],
          initialIndex: 0,
          likedPosts: {},
          savedPosts: {},
          followingUsers: const [],
        ));
      } else {
        Get.snackbar(
          'Post not found',
          'This post may have been deleted',
          backgroundColor: Colors.black,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('Error opening post: $e');
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 48,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Activity Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When someone likes, comments or follows you,\nit will show up here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No notifications found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}