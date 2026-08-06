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

  static const int FETCH_LIMIT = 20;

  static const Map<String, String> domainCategories = {
    'github.com': 'it_development',
    'gitlab.com': 'it_development',
    'stackoverflow.com': 'it_development',
    'codepen.io': 'it_development',
    'figma.com': 'design',
    'behance.net': 'design',
    'dribbble.com': 'design',
    'artstation.com': 'design',
    'notion.so': 'productivity',
    'miro.com': 'productivity',
    'canva.com': 'design',
    'instagram.com': 'social',
    'tiktok.com': 'social',
    'x.com': 'social',
    'twitter.com': 'social',
    'pinterest.com': 'social',
    'reddit.com': 'social',
    'facebook.com': 'social',
    'linkedin.com': 'social',
    'vk.com': 'social',
    'telegram.org': 'social',
    't.me': 'social',
    'discord.com': 'social',
    'snapchat.com': 'social',
    'whatsapp.com': 'social',
    'spotify.com': 'music',
    'soundcloud.com': 'music',
    'apple.com': 'music',
    'tidal.com': 'music',
    'deezer.com': 'music',
    'bandcamp.com': 'music',
    'youtube.com': 'video',
    'youtu.be': 'video',
    'vimeo.com': 'video',
    'twitch.tv': 'gaming',
    'bilibili.com': 'video',
    'netflix.com': 'entertainment',
    'primevideo.com': 'entertainment',
    'disneyplus.com': 'entertainment',
    'hbomax.com': 'entertainment',
    'max.com': 'entertainment',
    'hulu.com': 'entertainment',
    'kinopoisk.ru': 'entertainment',
    'ivi.ru': 'entertainment',
    'okko.tv': 'entertainment',
    'amazon.com': 'shopping',
    'ozon.ru': 'shopping',
    'ozon.by': 'shopping',
    'wildberries.ru': 'shopping',
    'wildberries.by': 'shopping',
    '21vek.by': 'shopping',
    'lamoda.ru': 'shopping',
    'kaspi.kz': 'shopping',
    'aliexpress.com': 'shopping',
    'ebay.com': 'shopping',
    'etsy.com': 'shopping',
    'shopify.com': 'shopping',
    'farfetch.com': 'shopping',
    'zalando.com': 'shopping',
    'asos.com': 'shopping',
    'shein.com': 'shopping',
    'nike.com': 'shopping',
    'adidas.com': 'shopping',
    'puma.com': 'shopping',
    'booking.com': 'travel',
    'agoda.com': 'travel',
    'airbnb.com': 'travel',
    'tripadvisor.com': 'travel',
    'skyscanner.net': 'travel',
    'kiwi.com': 'travel',
    'aviasales.ru': 'travel',
    'tutu.ru': 'travel',
    'rzd.ru': 'travel',
    'aeroflot.ru': 'travel',
    's7.ru': 'travel',
    'emirates.com': 'travel',
    'lufthansa.com': 'travel',
    'bbc.com': 'news',
    'bbc.co.uk': 'news',
    'cnn.com': 'news',
    'nytimes.com': 'news',
    'reuters.com': 'news',
    'apnews.com': 'news',
    'forbes.com': 'business',
    'bloomberg.com': 'business',
    'ft.com': 'business',
    'economist.com': 'business',
    'wsj.com': 'business',
    'tass.ru': 'news',
    'ria.ru': 'news',
    'lenta.ru': 'news',
    'gazeta.ru': 'news',
    'kommersant.ru': 'news',
    'vedomosti.ru': 'business',
    'coursera.org': 'education',
    'edx.org': 'education',
    'udemy.com': 'education',
    'skillshare.com': 'education',
    'khanacademy.org': 'education',
    'wikipedia.org': 'education',
    'skillbox.ru': 'education',
    'geekbrains.ru': 'education',
    'netology.ru': 'education',
    'stepik.org': 'education',
    'codecademy.com': 'education',
    'pluralsight.com': 'education',
    'delivery-club.ru': 'food',
    'foodora.com': 'food',
    'ubereats.com': 'food',
    'doordash.com': 'food',
    'deliveroo.com': 'food',
    'wolt.com': 'food',
    'foodpanda.com': 'food',
    'zomato.com': 'food',
    'webmd.com': 'health',
    'mayoclinic.org': 'health',
    'nhs.uk': 'health',
    'apteka.ru': 'health',
    'iherb.com': 'health',
    'paypal.com': 'finance',
    'stripe.com': 'finance',
    'wise.com': 'finance',
    'revolut.com': 'finance',
    'sberbank.ru': 'finance',
    'tinkoff.ru': 'finance',
    'alfabank.ru': 'finance',
    'steampowered.com': 'gaming',
    'epicgames.com': 'gaming',
    'gog.com': 'gaming',
    'itch.io': 'gaming',
    'hh.ru': 'job',
    'avito.ru': 'job',
    'upwork.com': 'job',
    'freelancer.com': 'job',
    'fiverr.com': 'job',
    'unsplash.com': 'photo',
    'pexels.com': 'photo',
    'shutterstock.com': 'photo',
    'drive.google.com': 'cloud',
    'dropbox.com': 'cloud',
    'onedrive.live.com': 'cloud',
    'icloud.com': 'cloud',
    'yandex.com': 'maps',
    'yandex.ru': 'maps',
    '2gis.ru': 'maps',
    '2gis.kz': 'maps',
    'mapbox.com': 'maps',
    'openstreetmap.org': 'maps',
    'fitnessfirst.ru': 'sport',
    'worldclass.ru': 'sport',
    'xfit.ru': 'sport',
    'decathlon.com': 'sport',
  };

  static String getCategoryForDomain(String domain) {
    final cleanDomain = domain.toLowerCase().replaceAll('www.', '');
    if (domainCategories.containsKey(cleanDomain)) {
      return domainCategories[cleanDomain]!;
    }
    for (final entry in domainCategories.entries) {
      if (cleanDomain.contains(entry.key) || entry.key.contains(cleanDomain)) {
        return entry.value;
      }
    }
    return 'general';
  }

  static String extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      return host.replaceAll('www.', '');
    } catch (_) {
      return '';
    }
  }

  static String getPostCategory(Map<String, dynamic> post) {
    if (post.containsKey('domainCategory') && post['domainCategory'] != null) {
      return post['domainCategory'] as String;
    }
    String? link = post['link'] ?? post['url'] ?? post['linkUrl'];
    if (link != null && link.isNotEmpty) {
      final domain = extractDomain(link);
      if (domain.isNotEmpty) {
        return getCategoryForDomain(domain);
      }
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
      print('📈 [Recommendation] Interest updated: $userId -> $category +1');
    } catch (e) {
      print('❌ [Recommendation] Error updating interest: $e');
    }
  }

  // ============================================================
  // 🔥 ЕДИНЫЙ МЕТОД ОБРАБОТКИ ПОСТА
  // ============================================================
  Map<String, dynamic> _processPost(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final postId = doc.id;
    
    // 🔥 ИЗВЛЕКАЕМ mediaType И videoUrl
    final mediaType = data['mediaType']?.toString() ?? 'photo';
    final videoUrl = data['videoUrl']?.toString();
    final thumbnailUrl = data['thumbnailUrl']?.toString();
    
    print('📦 [RECOMMENDATION] Post $postId: mediaType=$mediaType, videoUrl=$videoUrl');
    
    return {
      'id': postId,
      ...data,
      // 🔥 ЯВНО ДОБАВЛЯЕМ ПОЛЯ (ДАЖЕ ЕСЛИ ИХ НЕТ)
      'mediaType': mediaType,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  // ===== 1. ПОДПИСКИ (30%) =====
  Future<List<Map<String, dynamic>>> _getFollowingPosts(
    String userId,
    List<String> followingUsers, {
    DocumentSnapshot? lastDocument,
  }) async {
    if (followingUsers.isEmpty) return [];

    try {
      Query query = _firestore
          .collection('posts')
          .where('userId', whereIn: followingUsers.take(10).toList())
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        result.add(_processPost(doc));
      }
      return result;
    } catch (e) {
      print('❌ [Recommendation] Error fetching following posts: $e');
      return [];
    }
  }

  // ===== 2. ИНТЕРЕСЫ (40%) =====
  Future<List<Map<String, dynamic>>> _getInterestPosts(
    String userId, {
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final interests = await getUserInterests(userId);
      if (interests.isEmpty) return [];

      final sortedInterests = interests.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topCategories = sortedInterests.take(3).map((e) => e.key).toList();
      if (topCategories.isEmpty) return [];

      print('📊 [Recommendation] Top categories: $topCategories');

      final List<Map<String, dynamic>> allPosts = [];
      
      for (final category in topCategories) {
        try {
          Query query = _firestore
              .collection('posts')
              .where('domainCategory', isEqualTo: category)
              .orderBy('createdAt', descending: true)
              .limit(FETCH_LIMIT ~/ 2);

          if (lastDocument != null) {
            query = query.startAfterDocument(lastDocument);
          }

          final snapshot = await query.get();
          
          for (final doc in snapshot.docs) {
            allPosts.add(_processPost(doc));
          }
        } catch (e) {
          print('❌ [Recommendation] Error fetching category $category: $e');
        }
      }

      return allPosts;
    } catch (e) {
      print('❌ [Recommendation] Error fetching interest posts: $e');
      return [];
    }
  }

  // ===== 3. СВЕЖИЕ (20%) =====
  Future<List<Map<String, dynamic>>> _getFreshPosts({
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
      
      Query query = _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: twentyFourHoursAgo)
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT ~/ 2);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        result.add(_processPost(doc));
      }
      return result;
    } catch (e) {
      print('❌ [Recommendation] Error fetching fresh posts: $e');
      return [];
    }
  }

  // ===== 4. EXPLORER (10%) - РАНДОМНЫЕ ПОСТЫ =====
  Future<List<Map<String, dynamic>>> _getExplorerPosts() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final snapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThan: sevenDaysAgo)
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT)
          .get();

      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        result.add(_processPost(doc));
      }
      
      result.shuffle();
      return result;
    } catch (e) {
      print('❌ [Recommendation] Error fetching explorer posts: $e');
      return [];
    }
  }

  // ===== 5. 🔥 ВСЕ ОСТАЛЬНЫЕ ПОСТЫ (ЗАПАСНОЙ ВАРИАНТ) =====
  Future<List<Map<String, dynamic>>> _getRemainingPosts() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(FETCH_LIMIT)
          .get();

      final List<Map<String, dynamic>> result = [];
      for (final doc in snapshot.docs) {
        result.add(_processPost(doc));
      }
      return result;
    } catch (e) {
      print('❌ [Recommendation] Error fetching remaining posts: $e');
      return [];
    }
  }

  // ===== 6. ПЕРЕМЕШИВАНИЕ =====
  List<Map<String, dynamic>> _mixPosts({
    required List<Map<String, dynamic>> followingPosts,
    required List<Map<String, dynamic>> interestPosts,
    required List<Map<String, dynamic>> freshPosts,
    required List<Map<String, dynamic>> explorerPosts,
    required List<Map<String, dynamic>> remainingPosts,
  }) {
    final Set<String> seenIds = {};
    final List<Map<String, dynamic>> uniquePosts = [];
    
    final allPosts = [
      ...followingPosts,
      ...interestPosts,
      ...freshPosts,
      ...explorerPosts,
      ...remainingPosts,
    ];
    
    for (final post in allPosts) {
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
    DocumentSnapshot? lastDocument,
    bool refresh = false,
  }) async {
    print('🔄 [Recommendation] Getting personalized feed for user: $userId');

    try {
      final results = await Future.wait([
        _getFollowingPosts(userId, followingUsers ?? [], lastDocument: lastDocument),
        _getInterestPosts(userId, lastDocument: lastDocument),
        _getFreshPosts(lastDocument: lastDocument),
        _getExplorerPosts(),
        _getRemainingPosts(),
      ]);

      final followingPosts = results[0];
      final interestPosts = results[1];
      final freshPosts = results[2];
      final explorerPosts = results[3];
      final remainingPosts = results[4];

      print('📊 [Recommendation] Results:');
      print('   Following: ${followingPosts.length}');
      print('   Interests: ${interestPosts.length}');
      print('   Fresh: ${freshPosts.length}');
      print('   Explorer: ${explorerPosts.length}');
      print('   Remaining: ${remainingPosts.length}');

      final mixedPosts = _mixPosts(
        followingPosts: followingPosts,
        interestPosts: interestPosts,
        freshPosts: freshPosts,
        explorerPosts: explorerPosts,
        remainingPosts: remainingPosts,
      );

      print('✅ [Recommendation] Final feed: ${mixedPosts.length} posts');
      return mixedPosts;

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
    final score = (likes + clicks) / (hours + 2);
    return score.toDouble();
  }

  static Map<String, dynamic> enrichPostWithCategory(Map<String, dynamic> post) {
    final newPost = Map<String, dynamic>.from(post);
    String? link = post['link'] ?? post['url'] ?? post['linkUrl'];
    if (link != null && link.isNotEmpty) {
      final domain = extractDomain(link);
      if (domain.isNotEmpty) {
        final category = getCategoryForDomain(domain);
        newPost['domainCategory'] = category;
        newPost['linkDomain'] = domain;
        print('🏷️ [Recommendation] Post categorized: $domain -> $category');
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