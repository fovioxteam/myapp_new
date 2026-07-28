import 'package:flutter/material.dart';

class PlatformIcons {
  static IconData getIcon(String platform) {
    switch (platform) {
      // Музыка
      case 'spotify': return Icons.music_note;
      case 'soundcloud': return Icons.audiotrack;
      case 'apple_music': return Icons.apple;
      case 'tidal': return Icons.music_note;
      case 'deezer': return Icons.music_note;
      case 'bandcamp': return Icons.album;

      // Видео
      case 'youtube': return Icons.play_circle;
      case 'vimeo': return Icons.videocam;
      case 'twitch': return Icons.videocam;
      case 'bilibili': return Icons.video_library;

      // Соцсети
      case 'instagram': return Icons.photo_camera;
      case 'tiktok': return Icons.music_video;
      case 'x': return Icons.alternate_email;
      case 'pinterest': return Icons.push_pin;
      case 'reddit': return Icons.chat_bubble;
      case 'telegram': return Icons.send;
      case 'vk': return Icons.contacts;
      case 'facebook': return Icons.facebook;
      case 'linkedin': return Icons.work;
      case 'snapchat': return Icons.camera_alt;
      case 'discord': return Icons.gamepad;

      // Магазины
      case 'amazon': return Icons.shopping_bag;
      case 'ozon': return Icons.shopping_cart;
      case 'wildberries': return Icons.shopping_basket;
      case 'aliexpress': return Icons.local_mall;
      case 'ebay': return Icons.shopping_bag;
      case 'etsy': return Icons.storefront;
      case 'shopify': return Icons.storefront;
      case '21vek': return Icons.shopping_cart;
      case 'lamoda': return Icons.checkroom;
      case 'kaspi': return Icons.payments;
      case 'flipkart': return Icons.shopping_cart;
      case 'shopee': return Icons.shopping_bag;
      case 'lazada': return Icons.shopping_cart;
      case 'tokopedia': return Icons.store;
      case 'coupang': return Icons.shopping_bag;
      case 'rakuten': return Icons.shop;
      case 'zalando': return Icons.checkroom;
      case 'asos': return Icons.checkroom;
      case 'shein': return Icons.checkroom;
      case 'farfetch': return Icons.shopping_bag;

      // Стриминг
      case 'netflix': return Icons.movie;
      case 'primevideo': return Icons.play_circle;
      case 'disneyplus': return Icons.movie;
      case 'hbo': return Icons.movie;
      case 'hulu': return Icons.movie;
      case 'kinopoisk': return Icons.movie;
      case 'ivi': return Icons.movie;
      case 'okko': return Icons.movie;

      // IT / Дизайн
      case 'github': return Icons.code;
      case 'figma': return Icons.design_services;
      case 'behance': return Icons.brush;
      case 'dribbble': return Icons.brush;
      case 'artstation': return Icons.brush;
      case 'gitlab': return Icons.code;
      case 'codepen': return Icons.code;
      case 'stackoverflow': return Icons.code;

      // Игры
      case 'steam': return Icons.games;
      case 'epic': return Icons.games;
      case 'gog': return Icons.games;
      case 'itch': return Icons.games;

      // Книги / Образование
      case 'google_books': return Icons.menu_book;
      case 'litres': return Icons.menu_book;
      case 'audible': return Icons.headphones;
      case 'coursera': return Icons.school;
      case 'edx': return Icons.school;
      case 'udemy': return Icons.school;
      case 'skillshare': return Icons.school;
      case 'khanacademy': return Icons.school;
      case 'wikipedia': return Icons.menu_book;

      // Фото
      case 'unsplash': return Icons.photo;
      case 'pexels': return Icons.photo;
      case 'shutterstock': return Icons.photo;

      // Другое
      case 'notion': return Icons.note;
      case 'miro': return Icons.dashboard;
      case 'canva': return Icons.brush;
      case 'medium': return Icons.book;
      case 'substack': return Icons.email;

      default: return Icons.link;
    }
  }

  static Color getColor(String platform) {
    switch (platform) {
      case 'spotify': return Colors.green;
      case 'soundcloud': return Colors.orange;
      case 'apple_music': return Colors.red;
      case 'tidal': return Colors.blue;
      case 'deezer': return Colors.blue;
      case 'bandcamp': return Colors.blue;
      case 'youtube': return Colors.red;
      case 'vimeo': return Colors.blue;
      case 'twitch': return const Color(0xFF9146FF);
      case 'bilibili': return Colors.blue;
      case 'instagram': return const Color(0xFFE4405F);
      case 'tiktok': return Colors.black;
      case 'x': return Colors.white;
      case 'twitter': return Colors.white;
      case 'pinterest': return const Color(0xFFE60023);
      case 'reddit': return const Color(0xFFFF4500);
      case 'telegram': return const Color(0xFF0088CC);
      case 'vk': return const Color(0xFF0077FF);
      case 'facebook': return const Color(0xFF1877F2);
      case 'linkedin': return const Color(0xFF0A66C2);
      case 'snapchat': return const Color(0xFFFFFC00);
      case 'discord': return const Color(0xFF5865F2);
      case 'amazon': return Colors.orange;
      case 'ozon': return Colors.blue;
      case 'wildberries': return Colors.purple;
      case 'aliexpress': return Colors.orange;
      case 'ebay': return Colors.blue;
      case 'etsy': return Colors.orange;
      case 'shopify': return const Color(0xFF7AB55C);
      case '21vek': return Colors.red;
      case 'lamoda': return Colors.blue;
      case 'kaspi': return Colors.red;
      case 'flipkart': return Colors.blue;
      case 'shopee': return Colors.orange;
      case 'lazada': return Colors.red;
      case 'tokopedia': return Colors.green;
      case 'coupang': return Colors.blue;
      case 'rakuten': return Colors.red;
      case 'zalando': return Colors.blue;
      case 'asos': return Colors.black;
      case 'shein': return Colors.black;
      case 'farfetch': return const Color(0xFF6C2BD9);
      case 'netflix': return Colors.red;
      case 'primevideo': return Colors.blue;
      case 'disneyplus': return Colors.blue;
      case 'hbo': return Colors.purple;
      case 'hulu': return Colors.green;
      case 'kinopoisk': return Colors.blue;
      case 'ivi': return Colors.red;
      case 'okko': return Colors.blue;
      case 'github': return Colors.white;
      case 'figma': return Colors.purple;
      case 'behance': return const Color(0xFF1769FF);
      case 'dribbble': return const Color(0xFFEA4C89);
      case 'artstation': return Colors.blue;
      case 'gitlab': return Colors.orange;
      case 'codepen': return Colors.black;
      case 'stackoverflow': return Colors.orange;
      case 'steam': return const Color(0xFF171A21);
      case 'epic': return Colors.black;
      case 'gog': return Colors.red;
      case 'itch': return Colors.red;
      case 'google_books': return Colors.blue;
      case 'litres': return Colors.blue;
      case 'audible': return Colors.orange;
      case 'coursera': return const Color(0xFF2A73CC);
      case 'edx': return Colors.blue;
      case 'udemy': return const Color(0xFFA435F0);
      case 'skillshare': return const Color(0xFF00AB84);
      case 'khanacademy': return const Color(0xFF14B8A6);
      case 'wikipedia': return Colors.black;
      case 'unsplash': return Colors.black;
      case 'pexels': return const Color(0xFF05A081);
      case 'shutterstock': return const Color(0xFF0066CC);
      case 'notion': return Colors.black;
      case 'miro': return const Color(0xFF050038);
      case 'canva': return const Color(0xFF00C4CC);
      case 'medium': return Colors.black;
      case 'substack': return const Color(0xFFFF6719);
      default: return Colors.grey;
    }
  }
}