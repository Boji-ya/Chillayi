// lib/services/news_service.dart
//
// 嘉義市政府焦點新聞 — 官方 JSON API（最乾淨！）
// 來源：https://www.chiayi.gov.tw/OpenData.aspx?SN=16C8C46D376FCB28

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NewsItem {
  final String title;
  final String description;
  final String link;
  final String pubDate;
  final String imageUrl;
  final String category;

  const NewsItem({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
    required this.imageUrl,
    required this.category,
  });
}

class NewsService {
  // ✅ 嘉義市政府官方開放資料 JSON API
  static const String _jsonApiUrl =
      'https://www.chiayi.gov.tw/OpenData.aspx?SN=16C8C46D376FCB28';

  static const String _newsPageUrl =
      'https://www.chiayi.gov.tw/News2.aspx?n=454&sms=9149';

  Future<List<NewsItem>> fetchNews() async {
    final items = await _fetchFromJsonApi();
    if (items.isNotEmpty) return items;

    debugPrint('[NewsService] JSON API 失敗，使用示範資料');
    return _mockNews();
  }

  Future<List<NewsItem>> _fetchFromJsonApi() async {
    try {
      final resp = await http
          .get(Uri.parse(_jsonApiUrl))
          .timeout(const Duration(seconds: 15));

      debugPrint('[NewsService] HTTP ${resp.statusCode}');
      if (resp.statusCode != 200) return [];

      final List data = json.decode(resp.body);
      final result = <NewsItem>[];

      for (final item in data) {
        // 圖片：優先用 Thumbnail[0]，沒有才用 Pic[0]，都沒有用預設
        String imageUrl = '';
        final thumbs = item['Thumbnail'] as List? ?? [];
        final pics   = item['Pic']       as List? ?? [];
        if (thumbs.isNotEmpty) {
          imageUrl = thumbs[0]['filepath'] ?? '';
        } else if (pics.isNotEmpty) {
          imageUrl = pics[0]['filepath'] ?? '';
        }
        if (imageUrl.isEmpty) {
          imageUrl = _defaultImages[result.length % _defaultImages.length];
        }

        // 摘要：取 Content 前 80 字，去掉 HTML 標籤
        final rawContent = item['Content'] as String? ?? '';
        final cleanContent = rawContent
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&middot;', '·')
            .replaceAll('&amp;', '&')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final description = cleanContent.length > 80
            ? '${cleanContent.substring(0, 80)}...'
            : cleanContent;

        result.add(NewsItem(
          title:       item['title']    ?? '焦點新聞',
          description: description,
          link:        item['Source']   ?? _newsPageUrl,
          pubDate:     item['PostDate'] ?? '',
          imageUrl:    imageUrl,
          category:    '焦點新聞',
        ));

        if (result.length >= 10) break;
      }

      debugPrint('[NewsService] 🎉 成功取得 ${result.length} 則新聞');
      return result;
    } catch (e) {
      debugPrint('[NewsService] 例外: $e');
      return [];
    }
  }

  static const _defaultImages = [
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
    'https://images.unsplash.com/photo-1528360983277-13d401cdc186?w=800',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
    'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800',
  ];

  List<NewsItem> _mockNews() => [
    NewsItem(
      title: '全臺首創！嘉義市「火雞肉飯安衛家族」正式成立 26家業者攜手守護職場安全',
      description: '為凝聚嘉義市火雞肉飯業者力量、塑造安全職場環境，嘉義市政府今舉辦「火雞肉飯安衛家族」成立大會，邀集26家在地業者共同參與。',
      link: _newsPageUrl,
      pubDate: '2026/05/22',
      imageUrl: _defaultImages[0],
      category: '焦點新聞',
    ),
    NewsItem(
      title: '嘉市「來嘉BIKE訪」攜手CookieRun薑餅人 人氣爆表 報名再加開！',
      description: '連年受好評的「來嘉BIKE訪」嘉義市自行車日邁入第四屆，6月13日將於蘭潭登場，首度推出串聯蘭潭和仁義潭的雙潭路線。',
      link: _newsPageUrl,
      pubDate: '2026/05/22',
      imageUrl: _defaultImages[1],
      category: '焦點新聞',
    ),
    NewsItem(
      title: '近千萬補助助攻嘉市產業創新！黃敏惠市長宣布115年SBIR計劃開跑！',
      description: '嘉義市政府舉辦115年度SBIR計畫說明會，每案最高補助100萬元，總補助經費近千萬元，鼓勵在地企業投入創新研發。',
      link: _newsPageUrl,
      pubDate: '2026/05/21',
      imageUrl: _defaultImages[2],
      category: '焦點新聞',
    ),
    NewsItem(
      title: '《北城百畫帖》首度曝光嘉義取景 黃敏惠市長力挺臺灣本土漫畫IP',
      description: '公視台語台年度重磅影集《北城百畫帖》於嘉義市展開密集拍攝，嘉義市長黃敏惠特別前往舊嘉義菸葉廠探班。',
      link: _newsPageUrl,
      pubDate: '2026/05/19',
      imageUrl: _defaultImages[3],
      category: '焦點新聞',
    ),
    NewsItem(
      title: '賞花又種花！阿勃勒花季串聯潮選店與皮克敏熱潮 打造最療癒的城市散步提案',
      description: '阿勃勒花季到來，嘉義市街頭披上金黃色花景。嘉義市政府邀請民眾把握初夏時節，走訪特色景點與「潮選店」。',
      link: _newsPageUrl,
      pubDate: '2026/05/17',
      imageUrl: _defaultImages[4],
      category: '焦點新聞',
    ),
  ];
}