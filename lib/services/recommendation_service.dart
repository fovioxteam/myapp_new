// lib/services/recommendation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/link_utils.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 Синхронизировано с _pageSize = 30
  static const int FETCH_LIMIT = 30;

  static const Map<String, String> domainCategories = {
    'github.com': 'it_development', 'gitlab.com': 'it_development', 'stackoverflow.com': 'it_development', 'codepen.io': 'it_development',
    'figma.com': 'design', 'behance.net': 'design', 'dribbble.com': 'design', 'artstation.com': 'design',
    'notion.so': 'productivity', 'miro.com': 'productivity',
    'canva.com': 'design', 'instagram.com': 'social', 'tiktok.com': 'social', 'x.com': 'social',
    'twitter.com': 'social', 'pinterest.com': 'social', 'reddit.com': 'social', 'facebook.com': 'social',
    'linkedin.com': 'social', 'vk.com': 'social', 'telegram.org': 'social', 't.me': 'social',
    'discord.com': 'social', 'snapchat.com': 'social', 'whatsapp.com': 'social', 'spotify.com': 'music',
    'soundcloud.com': 'music', 'apple.com': 'music', 'tidal.com': 'music', 'deezer.com': 'music',
    'bandcamp.com': 'music', 'youtube.com': 'video', 'youtu.be': 'video', 'vimeo.com': 'video',
    'twitch.tv': 'gaming', 'bilibili.com': 'video', 'netflix.com': 'entertainment', 'primevideo.com': 'entertainment',
    'disneyplus.com': 'entertainment', 'hbomax.com': 'entertainment', 'max.com': 'entertainment', 'hulu.com': 'entertainment',
    'kinopoisk.ru': 'entertainment', 'ivi.ru': 'entertainment', 'okko.tv': 'entertainment', 'amazon.com': 'shopping',
    'ozon.ru': 'shopping', 'ozon.by': 'shopping', 'wildberries.ru': 'shopping', 'wildberries.by': 'shopping',
    '21vek.by': 'shopping', 'lamoda.ru': 'shopping', 'kaspi.kz': 'shopping', 'aliexpress.com': 'shopping',
    'ebay.com': 'shopping', 'etsy.com': 'shopping', 'shopify.com': 'shopping', 'farfetch.com': 'shopping',
    'zalando.com': 'shopping', 'asos.com': 'shopping', 'shein.com': 'shopping', 'nike.com': 'shopping',
    'adidas.com': 'shopping', 'puma.com': 'shopping', 'booking.com': 'travel', 'agoda.com': 'travel',
    'airbnb.com': 'travel', 'tripadvisor.com': 'travel', 'skyscanner.net': 'travel', 'kiwi.com': 'travel',
    'aviasales.ru': 'travel', 'tutu.ru': 'travel', 'rzd.ru': 'travel', 'aeroflot.ru': 'travel',
    's7.ru': 'travel', 'emirates.com': 'travel', 'lufthansa.com': 'travel', 'bbc.com': 'news',
    'bbc.co.uk': 'news', 'cnn.com': 'news', 'nytimes.com': 'news', 'reuters.com': 'news',
    'apnews.com': 'news', 'forbes.com': 'business', 'bloomberg.com': 'business', 'ft.com': 'business',
    'economist.com': 'business', 'wsj.com': 'business', 'tass.ru': 'news', 'ria.ru': 'news',
    'lenta.ru': 'news', 'gazeta.ru': 'news', 'kommersant.ru': 'news', 'vedomosti.ru': 'business',
    'coursera.org': 'education', 'edx.org': 'education', 'udemy.com': 'education', 'skillshare.com': 'education',
    'khanacademy.org': 'education', 'wikipedia.org': 'education', 'skillbox.ru': 'education', 'geekbrains.ru': 'education',
    'netology.ru': 'education', 'stepik.org': 'education', 'codecademy.com': 'education', 'pluralsight.com': 'education',
    'delivery-club.ru': 'food', 'foodora.com': 'food', 'ubereats.com': 'food', 'doordash.com': 'food',
    'deliveroo.com': 'food', 'wolt.com': 'food', 'foodpanda.com': 'food', 'zomato.com': 'food',
    'webmd.com': 'health', 'mayoclinic.org': 'health', 'nhs.uk': 'health', 'apteka.ru': 'health',
    'iherb.com': 'health', 'paypal.com': 'finance', 'stripe.com': 'finance', 'wise.com': 'finance',
    'revolut.com': 'finance', 'sberbank.ru': 'finance', 'tinkoff.ru': 'finance', 'alfabank.ru': 'finance',
    'steampowered.com': 'gaming', 'epicgames.com': 'gaming', 'gog.com': 'gaming', 'itch.io': 'gaming',
    'hh.ru': 'job', 'avito.ru': 'job', 'upwork.com': 'job', 'freelancer.com': 'job',
    'fiverr.com': 'job', 'unsplash.com': 'photo', 'pexels.com': 'photo', 'shutterstock.com': 'photo',
    'drive.google.com': 'cloud', 'dropbox.com': 'cloud', 'onedrive.live.com': 'cloud', 'icloud.com': 'cloud',
    'yandex.com': 'maps', 'yandex.ru': 'maps', '2gis.ru': 'maps', '2gis.kz': 'maps',
    'mapbox.com': 'maps', 'openstreetmap.org': 'maps', 'fitnessfirst.ru': 'sport', 'worldclass.ru': 'sport',
    'xfit.ru': 'sport', 'decathlon.com': 'sport',
  };

  static String getCategoryForDomain(String domain) {
    final cleanDomain = domain.toLowerCase().replaceAll('www.', '');
    if (domainCategories.containsKey(cleanDomain)) return domainCategories[cleanDomain]!;
    for (final entry in domainCategories.entries) {
      if (cleanDomain.contains(entry.key) || entry.key.contains(cleanDomain)) return entry.value;
    }
    return 'general';
  }

  static String extractDomain(String url) {
    try {
      return Uri.parse(url).host.replaceAll('www.', '');
    } catch (_) {
      return '';
    }
  }

  static String getPostCategory(Map<String, dynamic> post) {
    if (post.containsKey('domainCategory') && post['domainCategory'] != null) return post['domainCategory'] as String;
    String? link = post['link'] ?? post['url'] ?? post['linkUrl'];
    if (link != null && link.isNotEmpty) {
      final domain = extractDomain(link);
      if (domain.isNotEmpty) return getCategoryForDomain(domain);
    }
    return 'general';
  }

  Future<Map<String, int>> getUserInterests(String userId) async {
    try {
      final doc = await _firestore.collection('user_interests').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data.map((key, value) => MapEntry(key, (value as num).toInt()));
      }
    } catch (e) {
      print('❌ [Recommendation] Error loading interests: $e');
    }
    return {};
  }

  Future<void> updateUserInterest(String userId, String category) async {
    if (userId.isEmpty || category.isEmpty || category == 'general') return;
    try {
      await _firestore.collection('user_interests').doc(userId).set(
        {category: FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      print('❌ [Recommendation] Error updating interest: $e');
    }
  }

  Map<String, dynamic> _processPost(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final postId = doc.id;
    final mediaType = data['mediaType']?.toString() ?? 'photo';
    final videoUrl = data['videoUrl']?.toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    
    return {
      'id': postId,
      ...data,
      'mediaType': mediaType,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  // 🔥 УНИВЕРСАЛЬНЫЙ ФИЛЬТР SEEN
  List<Map<String, dynamic>> _filterSeen(List<Map<String, dynamic>> posts, Set<String> seenPosts) {
    if (seenPosts.isEmpty) return posts;
    return posts.where((p) => !seenPosts.contains(p['id'])).toList();
  }

  // ===== 1. ПОДПИСКИ =====
  Future<List<Map<String, dynamic>>> _getFollowingPosts(String userId, List<String> followingUsers, Set<String> seenPosts) async {
    if (followingUsers.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: followingUsers.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT)
          .get();
      return _filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts);
    } catch (e) {
      print('❌ [Recommendation] Error fetching following: $e');
      return [];
    }
  }

  // ===== 2. ИНТЕРЕСЫ =====
  Future<List<Map<String, dynamic>>> _getInterestPosts(String userId, Set<String> seenPosts) async {
    try {
      final interests = await getUserInterests(userId);
      if (interests.isEmpty) return [];
      final topCategories = (interests.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => e.key).toList();
      if (topCategories.isEmpty) return [];

      final List<Map<String, dynamic>> allPosts = [];
      for (final category in topCategories) {
        try {
          final snapshot = await _firestore
              .collection('posts')
              .where('domainCategory', isEqualTo: category)
              .orderBy('createdAt', descending: true)
              .limit(FETCH_LIMIT ~/ 2)
              .get();
          allPosts.addAll(_filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts));
        } catch (e) {
          print('❌ [Recommendation] Error fetching category $category: $e');
        }
      }
      return allPosts;
    } catch (e) {
      print('❌ [Recommendation] Error fetching interests: $e');
      return [];
    }
  }

  // ===== 3. СВЕЖИЕ =====
  Future<List<Map<String, dynamic>>> _getFreshPosts(Set<String> seenPosts) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)))
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT ~/ 2)
          .get();
      return _filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts);
    } catch (e) {
      print('❌ [Recommendation] Error fetching fresh: $e');
      return [];
    }
  }

  // ===== 4. EXPLORER =====
  Future<List<Map<String, dynamic>>> _getExplorerPosts(Set<String> seenPosts) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT)
          .get();
      var result = _filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts);
      result.shuffle();
      return result;
    } catch (e) {
      print('❌ [Recommendation] Error fetching explorer: $e');
      return [];
    }
  }

  // ===== 5. ОСТАЛЬНЫЕ =====
  Future<List<Map<String, dynamic>>> _getRemainingPosts(Set<String> seenPosts) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT)
          .get();
      return _filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts);
    } catch (e) {
      print('❌ [Recommendation] Error fetching remaining: $e');
      return [];
    }
  }

  // ===== 6. МИКСЕР =====
  List<Map<String, dynamic>> _mixPosts({
    required List<Map<String, dynamic>> followingPosts,
    required List<Map<String, dynamic>> interestPosts,
    required List<Map<String, dynamic>> freshPosts,
    required List<Map<String, dynamic>> explorerPosts,
    required List<Map<String, dynamic>> remainingPosts,
  }) {
    final Set<String> seenIds = {};
    final List<Map<String, dynamic>> uniquePosts = [];

    for (final post in [...followingPosts, ...interestPosts, ...freshPosts, ...explorerPosts, ...remainingPosts]) {
      final id = post['id']?.toString() ?? '';
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        uniquePosts.add(post);
      }
    }
    uniquePosts.shuffle();
    return uniquePosts;
  }

  // ===== 7. ГЛАВНЫЙ МЕТОД =====
  Future<List<Map<String, dynamic>>> getPersonalizedFeed({
    required String userId,
    List<String>? followingUsers,
    required Set<String> seenPosts, // 🔥 Передается из памяти
    DocumentSnapshot? lastDocument,
    bool refresh = false,
  }) async {
    print('🔄 [Recommendation] Feed for $userId, seen=${seenPosts.length}');

    try {
      // ========== ПАГИНАЦИЯ (ЧИСТЫЙ КУРСОР) ==========
      if (lastDocument != null && !refresh) {
        final takeCount = seenPosts.isEmpty ? FETCH_LIMIT : FETCH_LIMIT * 2;
        final snapshot = await _firestore
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .startAfterDocument(lastDocument)
            .limit(takeCount)
            .get();

        var posts = _filterSeen(snapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts);

        // Если отфильтровали много — добираем еще
        if (posts.length < FETCH_LIMIT && seenPosts.isNotEmpty && snapshot.docs.isNotEmpty) {
          final moreSnapshot = await _firestore
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .startAfterDocument(snapshot.docs.last)
              .limit(FETCH_LIMIT)
              .get();
          posts.addAll(_filterSeen(moreSnapshot.docs.map((doc) => _processPost(doc)).toList(), seenPosts));
        }
        return posts.take(FETCH_LIMIT).toList();
      }

      // ========== ПЕРВАЯ СТРАНИЦА ==========
      final results = await Future.wait([
        _getFollowingPosts(userId, followingUsers ?? [], seenPosts),
        _getInterestPosts(userId, seenPosts),
        _getFreshPosts(seenPosts),
        _getExplorerPosts(seenPosts),
        _getRemainingPosts(seenPosts),
      ]);

      final mixedPosts = _mixPosts(
        followingPosts: results[0],
        interestPosts: results[1],
        freshPosts: results[2],
        explorerPosts: results[3],
        remainingPosts: results[4],
      );

      // Fallback (все просмотрено)
      if (mixedPosts.isEmpty && seenPosts.isNotEmpty) {
        final fallback = await _firestore.collection('posts').orderBy('createdAt', descending: true).limit(FETCH_LIMIT).get();
        return fallback.docs.map((doc) => _processPost(doc)).toList();
      }

      return mixedPosts.take(FETCH_LIMIT).toList();
    } catch (e) {
      print('❌ [Recommendation] Error: $e');
      return [];
    }
  }

  static double calculateHotScore(Map<String, dynamic> post) {
    final likes = (post['likes'] ?? 0) as num;
    final clicks = (post['clicks'] ?? 0) as num;
    final createdAt = post['createdAt'] as Timestamp?;
    if (createdAt == null) return 0.0;
    final hours = DateTime.now().difference(createdAt.toDate()).inHours;
    return ((likes + clicks) / (hours + 2)).toDouble();
  }

  static Map<String, dynamic> enrichPostWithCategory(Map<String, dynamic> post) {
    final newPost = Map<String, dynamic>.from(post);
    String? link = post['link'] ?? post['url'] ?? post['linkUrl'];
    if (link != null && link.isNotEmpty) {
      final domain = extractDomain(link);
      if (domain.isNotEmpty) {
        newPost['domainCategory'] = getCategoryForDomain(domain);
        newPost['linkDomain'] = domain;
      } else {
        newPost['domainCategory'] = 'general';
      }
    } else {
      newPost['domainCategory'] = 'general';
    }
    if (!newPost.containsKey('clicks')) newPost['clicks'] = 0;
    if (!newPost.containsKey('hotScore')) newPost['hotScore'] = 0.0;
    return newPost;
  }
}