// lib/widgets/comments_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../controllers/post_controller.dart';
import '../controllers/profile_controller.dart';
import '../screens/profile_screen.dart' as profile;
import '../screens/user_profile_screen.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String photoId;
  final String postOwnerId;
  final String postImageUrl;

  const CommentsBottomSheet({
    super.key,
    required this.photoId,
    required this.postOwnerId,
    required this.postImageUrl,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  
  final PostController _postController = Get.find<PostController>();
  final ProfileController _profileController = Get.find<ProfileController>();

  String? _replyingToUserId;
  String? _replyingToUsername;
  String? _replyingToCommentId;

  final Map<String, bool> _expandedReplies = {};

  final ScrollController _scrollController = ScrollController();

  // Пагинация
  final int _pageSize = 20;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _totalComments = 0;

  @override
  void initState() {
    super.initState();
    print('📱 [CommentsBottomSheet] INIT for post: ${widget.photoId}');
    _loadTotalComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadTotalComments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.photoId)
          .collection('comments')
          .count()
          .get();
      setState(() {
        _totalComments = snapshot.count ?? 0;
      });
    } catch (e) {
      print('Error loading total comments: $e');
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.photoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }
      
      final snapshot = await query.get();
      
      setState(() {
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
      
    } catch (e) {
      print('Error loading more comments: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingToUserId = null;
      _replyingToUsername = null;
      _replyingToCommentId = null;
    });
  }

  List<String> _extractMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(text);
    return matches.map((match) => match.group(1)!).toList();
  }

  Future<String?> _getUserIdByUsername(String username) async {
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.id;
      }
    } catch (e) {
      print('Error finding user by username: $e');
    }
    return null;
  }

  Future<void> _sendNotification({
    required String userId,
    required String type,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String title,
    required String body,
    String? postId,
    String? commentId,
    String? commentText,
  }) async {
    if (userId == senderId) return;
    
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': type,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'title': title,
        'body': body,
        'postId': postId,
        'commentId': commentId,
        'commentText': commentText,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Notification sent to: $userId (type: $type)');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isSending) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isSending = true);

    print('\n📝📝📝 [CommentsBottomSheet] ========== ADDING COMMENT ==========');
    print('📝 Post ID: ${widget.photoId}');
    print('📝 Comment text: "$text"');

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? currentUser.displayName ?? 'User';
      final userAvatar = userData['avatarUrl'] ?? currentUser.photoURL ?? '';

      final Map<String, dynamic> commentData = {
        'text': text,
        'userId': currentUser.uid,
        'username': username,
        'userAvatar': userAvatar,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      };

      String? commentId;
      
      if (_replyingToUserId != null) {
        commentData['replyToUserId'] = _replyingToUserId;
        commentData['replyToUsername'] = _replyingToUsername;
        commentData['replyToCommentId'] = _replyingToCommentId;
        commentData['parentId'] = _replyingToCommentId;
      }

      final docRef = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.photoId)
          .collection('comments')
          .add(commentData);
      
      commentId = docRef.id;

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.photoId)
          .update({
        'comments': FieldValue.increment(1),
      });

      _postController.incrementComments(widget.photoId);
      
      print('✅ Comment added and counter incremented in PostController');

      // Отправка уведомлений
      if (widget.postOwnerId != currentUser.uid && _replyingToUserId == null) {
        await _sendNotification(
          userId: widget.postOwnerId,
          type: 'comment',
          senderId: currentUser.uid,
          senderName: username,
          senderAvatar: userAvatar,
          title: 'New Comment',
          body: 'commented on your post: "$text"',
          postId: widget.photoId,
          commentId: commentId,
          commentText: text,
        );
      }
      
      if (_replyingToUserId != null && _replyingToUserId != currentUser.uid) {
        await _sendNotification(
          userId: _replyingToUserId!,
          type: 'comment',
          senderId: currentUser.uid,
          senderName: username,
          senderAvatar: userAvatar,
          title: 'New Reply',
          body: 'replied to your comment: "$text"',
          postId: widget.photoId,
          commentId: commentId,
          commentText: text,
        );
      }
      
      final mentions = _extractMentions(text);
      for (final mentionedUsername in mentions) {
        final mentionedUserId = await _getUserIdByUsername(mentionedUsername);
        if (mentionedUserId != null && mentionedUserId != currentUser.uid) {
          await _sendNotification(
            userId: mentionedUserId,
            type: 'mention',
            senderId: currentUser.uid,
            senderName: username,
            senderAvatar: userAvatar,
            title: 'Mention',
            body: 'mentioned you in a comment: "$text"',
            postId: widget.photoId,
            commentId: commentId,
            commentText: text,
          );
        }
      }
      
      print('📝📝📝 ========== COMMENT ADDED SUCCESSFULLY ==========\n');

      _controller.clear();
      _cancelReply();

      setState(() {
        _totalComments++;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });

    } catch (e) {
      print('❌❌❌ [CommentsBottomSheet] ERROR adding comment: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike(String commentId, List<String> likedBy, int currentLikes) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.photoId)
          .collection('comments')
          .doc(commentId);

      if (likedBy.contains(currentUser.uid)) {
        likedBy.remove(currentUser.uid);
        await commentRef.update({
          'likedBy': likedBy,
          'likes': currentLikes - 1,
        });
      } else {
        likedBy.add(currentUser.uid);
        await commentRef.update({
          'likedBy': likedBy,
          'likes': currentLikes + 1,
        });
      }
    } catch (e) {
      print('❌ Error toggling like: $e');
    }
  }

  void _setReply(String userId, String username, String commentId) {
    setState(() {
      _replyingToUserId = userId;
      _replyingToUsername = username;
      _replyingToCommentId = commentId;
    });
    _focusNode.requestFocus();
  }

  void _toggleReplies(String commentId) {
    setState(() {
      _expandedReplies[commentId] = !(_expandedReplies[commentId] ?? false);
    });
  }

  void _navigateToProfile(String userId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId != null && userId == currentUserId) {
      Navigator.pop(context);
      if (Get.currentRoute == '/profile') {
        print('📱 Already on profile screen');
      } else {
        Get.toNamed('/profile');
      }
      _profileController.refreshCounters(currentUserId);
    } else {
      print('📱 [CommentsBottomSheet] Navigating to user profile: $userId');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(userId: userId),
        ),
      );
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;
    final keyboardOpen = bottomPadding > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: keyboardOpen ? 0.9 : 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Уменьшенный счетчик комментариев
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    '$_totalComments comments',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),

                // Comments list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.photoId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .limit(_pageSize)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load comments',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[600]
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments = snapshot.data!.docs;

                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.chat_bubble, color: Colors.grey[300], size: 56),
                              const SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to comment',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final rootComments = comments
                          .where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['replyToCommentId'] == null;
                          })
                          .toList();

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: rootComments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentTile(rootComments[index], comments);
                        },
                      );
                    },
                  ),
                ),

                // Reply indicator
                if (_replyingToUserId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[100],
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Replying to @$_replyingToUsername',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _cancelReply,
                          icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                // Input field (без упоминания про @)
                Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 8,
                    top: 8,
                    bottom: bottomPadding > 0 ? bottomPadding : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (text) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: _replyingToUserId != null
                                  ? 'Reply to @$_replyingToUsername...'
                                  : 'Add a comment...',  // 🔥 УБРАНО " (use @ to mention)"
                              hintStyle: TextStyle(
                                fontSize: 15,
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            onSubmitted: (_) => _addComment(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: (_controller.text.trim().isNotEmpty && !_isSending)
                              ? _addComment
                              : null,
                          icon: Icon(
                            Icons.send,
                            color: (_controller.text.trim().isNotEmpty && !_isSending)
                                ? Colors.black
                                : Colors.grey[400],
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentTile(DocumentSnapshot commentDoc, List<DocumentSnapshot> allComments) {
    final comment = commentDoc.data() as Map<String, dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;
    final commentId = commentDoc.id;
    final likedBy = List<String>.from(comment['likedBy'] ?? []);
    final isLiked = currentUser != null && likedBy.contains(currentUser.uid);
    final timestamp = comment['createdAt'] as Timestamp?;

    final replies = allComments
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['replyToCommentId'] == commentId;
        })
        .toList();

    final hasReplies = replies.isNotEmpty;
    final isExpanded = _expandedReplies[commentId] ?? false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватарка (30x30)
                GestureDetector(
                  onTap: () => _navigateToProfile(comment['userId']),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                      image: (comment['userAvatar']?.isNotEmpty ?? false)
                          ? DecorationImage(
                              image: NetworkImage(comment['userAvatar']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (comment['userAvatar']?.isEmpty ?? true)
                        ? Icon(Icons.person, color: Colors.grey[400], size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Никнейм
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProfile(comment['userId']),
                            child: Text(
                              comment['username'] ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              _getTimeAgo(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      
                      // Текст комментария
                      Text(
                        comment['text'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[900],
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                      
                      // Показываем на кого ответ
                      if (comment['replyToUsername'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Replying to @${comment['replyToUsername']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 5),

                      // Кнопка Reply
                      GestureDetector(
                        onTap: () => _setReply(
                          comment['userId'],
                          comment['username'] ?? 'User',
                          commentDoc.id,
                        ),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Кнопка лайка
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: () => _toggleLike(
                      commentId,
                      likedBy,
                      comment['likes'] ?? 0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.black : Colors.grey[400],
                            size: 14,
                          ),
                          if ((comment['likes'] ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${comment['likes']}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isLiked ? Colors.black : Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Replies
        if (hasReplies)
          Column(
            children: [
              // Кнопка показа/скрытия ответов
              Padding(
                padding: const EdgeInsets.only(left: 46, right: 16, bottom: 4),
                child: GestureDetector(
                  onTap: () => _toggleReplies(commentId),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isExpanded ? 'Hide replies' : 'View ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Ответы
              if (isExpanded)
                ...replies.map((replyDoc) => _buildCommentTile(replyDoc, allComments)),
            ],
          ),
      ],
    );
  }
}