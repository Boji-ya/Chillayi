// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/place_model.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import '../services/firestore_service.dart';
import 'map_page.dart';
import 'profile_page.dart';
import 'detail_page.dart';
import 'category_list_page.dart';
import 'transport_page.dart';
import '../services/news_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ai_assistant_page.dart';
import 'community_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    context.read<FavoritesService>().load();
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0:
        return const _HomeTab();
      case 1:
        return const CategoryMapPage(category: 'attraction', title: '地圖探索');
      case 2:
        return const CommunityPage();
      case 3:
        return const AiAssistantPage();
      case 4:
        return const ProfilePage();
      default:
        return const _HomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_tab), child: _buildBody()),
      ),
      bottomNavigationBar: _AppBottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AppBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              _NavItem(icon: 'images/homeicon.png', activeIcon: 'images/homeicon.png', label: '首頁',   index: 0, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: 'images/mapicon.png', activeIcon: 'images/mapicon.png', label: '地圖',   index: 1, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: 'images/communityicon.png', activeIcon: 'images/communityicon.png', label: '社群',   index: 2, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: 'images/aiicon.png', activeIcon: 'images/aiicon.png', label: 'AI助手', index: 3, currentIndex: currentIndex, onTap: onTap),
              _NavItem(icon: 'images/profileicon.png', activeIcon: 'images/profileicon.png', label: '個人',   index: 4, currentIndex: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _NavItem({
    required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.currentIndex, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Opacity(
                opacity: selected ? 1.0 : 0.4,
                key: ValueKey(selected),
                child: Image.asset(
                  selected ? activeIcon : icon,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: const Color(0xFF2A5080),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Home Tab ──────────────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          // ── Illustrated landscape background ──────────────────────────────
          const Positioned(
            top: 0, left: 0, right: 0,
            child: _LandscapeBackground(),
          ),
          // ── Scrollable content ────────────────────────────────────────────
          SafeArea(
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _header(context)),
              // Spacer so content starts below the tallest part of the landscape
              const SliverToBoxAdapter(child: SizedBox(height: 200)),
              SliverToBoxAdapter(child: _eventsBanner(context)),
              SliverToBoxAdapter(child: _quickExploreSection(context)),
              SliverToBoxAdapter(child: _favoritesMapSection(context)),
              SliverToBoxAdapter(child: const _WeatherSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('歡迎，${auth.userModel?.username ?? '旅行者'} 👋',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 8)])),
          const Text('探索嘉義的美好旅程',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  shadows: [Shadow(color: Colors.black12, blurRadius: 4)])),
        ]),
        const Spacer(),
      ]),
    );
  }

  // ── Events Banner ─────────────────────────────────────────────────────────
  Widget _eventsBanner(BuildContext context) {
    return FutureBuilder<List<NewsItem>>(
      future: NewsService().fetchNews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 250,
            child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 250,
            child: Center(child: Text('目前暫無最新消息',
                style: TextStyle(color: AppTheme.textGrey))),
          );
        }
        final newsList = snapshot.data!;
        return _EventsBannerCarousel(
          banners: newsList.map((n) => n.imageUrl).toList(),
          titles:  newsList.map((n) => n.title).toList(),
          subs:    newsList.map((n) => n.pubDate).toList(),
          links:   newsList.map((n) => n.link).toList(),
        );
      },
    );
  }

  // ── Quick Explore Section ────────────────────────────────────────────────
  Widget _quickExploreSection(BuildContext context) {
    final categories = [
      const _QuickCat('attraction', '景點',  'images/attractionicon.png', Color(0xFF3DAA6D), Color(0xFFE8F5EE)),
      const _QuickCat('restaurant', '餐廳',  'images/resticon.png',       Color(0xFFEA580C), Color(0xFFFFF0E8)),
      const _QuickCat('hotel',      '住宿',  'images/accomodation.png',   Color(0xFF2563EB), Color(0xFFE8F0FF)),
      const _QuickCat('event',      '活動',  'images/eventsicon.png',     Color(0xFF7C3AED), Color(0xFFF3EEFF)),
      const _QuickCat('transport',  '交通',  'images/busicon.png',        Color(0xFF0D9488), Color(0xFFE6F6F5)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('快速探索',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 12),
        Row(children: categories.take(3).map((c) =>
            Expanded(child: _QuickCatTile(cat: c, large: true)),
        ).toList()),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(flex: 1, child: SizedBox()),
          ...categories.skip(3).map((c) =>
              Expanded(flex: 3, child: _QuickCatTile(cat: c, large: true))),
          const Expanded(flex: 1, child: SizedBox()),
        ]),
      ]),
    );
  }

  // ── Favorites Map Section ────────────────────────────────────────────────
  Widget _favoritesMapSection(BuildContext context) {
    final fav = context.watch<FavoritesService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('我的收藏地圖',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),

        ]),
        const SizedBox(height: 12),
        _FavoriteMapPreview(favoriteIds: fav.favorites),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _LandscapeBackground extends StatefulWidget {
  const _LandscapeBackground();

  @override
  State<_LandscapeBackground> createState() => _LandscapeBackgroundState();
}

class _LandscapeBackgroundState extends State<_LandscapeBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // The windmill does one full rotation every 12 seconds, repeating endlessly
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            // Pass the rotation angle (0 to 2*Pi) to the painter
            painter: _LandscapePainter(rotationAngle: _controller.value * 2 * 3.14159265359),
          );
        },
      ),
    );
  }
}

class _LandscapePainter extends CustomPainter {
  final double rotationAngle;

  _LandscapePainter({required this.rotationAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── 1. Sky ───────────────────────────────────────────────────────────────
    final skyPaint = Paint()..color = const Color(0xFFB1D4E5);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // ── 2. Distant Background Clouds (Soft blue layer) ───────────────────────
    final bgCloudPaint = Paint()..color = const Color(0xFFC9E4F2);
    canvas.drawCircle(Offset(w * 0.1, h * 0.35), 70, bgCloudPaint);
    canvas.drawCircle(Offset(w * 0.45, h * 0.3), 90, bgCloudPaint);
    canvas.drawCircle(Offset(w * 0.85, h * 0.4), 80, bgCloudPaint);
    canvas.drawCircle(Offset(w * 1.0, h * 0.45), 60, bgCloudPaint);

    // ── 3. White Fluffy Clouds ───────────────────────────────────────────────
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.9);
    void drawCloud(double cx, double cy, double scale) {
      canvas.drawCircle(Offset(cx, cy), 14 * scale, cloudPaint);
      canvas.drawCircle(Offset(cx - 14 * scale, cy + 4 * scale), 10 * scale, cloudPaint);
      canvas.drawCircle(Offset(cx + 14 * scale, cy + 4 * scale), 10 * scale, cloudPaint);
      canvas.drawRect(
        Rect.fromLTRB(cx - 14 * scale, cy, cx + 14 * scale, cy + 14 * scale),
        cloudPaint,
      );
    }
    drawCloud(w * 0.15, h * 0.15, 1.2);
    drawCloud(w * 0.45, h * 0.08, 0.9);
    drawCloud(w * 0.85, h * 0.22, 1.1);

    // ── 4. Setting Sun ───────────────────────────────────────────────────────
    final sunPaint = Paint()..color = const Color(0xFFF7B451);
    canvas.drawCircle(Offset(w * 0.32, h * 0.53), 50, sunPaint);

    // ── 5. Back Right Hill (Light Green) ─────────────────────────────────────
    final hill1 = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.6, h * 0.25, w * 1.1, h * 0.7)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill1, Paint()..color = const Color(0xFFA5CD89));

    // ── 6. Back Left Hill (Light Green) ──────────────────────────────────────
    final hill2 = Path()
      ..moveTo(-w * 0.2, h)
      ..quadraticBezierTo(w * 0.2, h * 0.4, w * 0.6, h * 0.72)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hill2, Paint()..color = const Color(0xFF91C371));

    // ── 7. Mid Right Hill (Darker Olive Green) ───────────────────────────────
    final hill3 = Path()
      ..moveTo(w * 0.4, h)
      ..quadraticBezierTo(w * 0.8, h * 0.62, w * 1.2, h * 0.85)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill3, Paint()..color = const Color(0xFF4A6B32));

    // ── 8. Foreground Hill / Ground (Soft Green) ─────────────────────────────
    final groundPath = Path()
      ..moveTo(0, h * 0.82)
      ..quadraticBezierTo(w * 0.4, h * 0.76, w, h * 0.82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(groundPath, Paint()..color = const Color(0xFF86B361));

    // ── 9. Winding Dirt Path (Yellow/Orange) ─────────────────────────────────
    final pathDraw = Path()
      ..moveTo(w * 0.2, h)
      ..quadraticBezierTo(w * 0.5, h * 0.8, w * 0.75, h * 0.74)
      ..lineTo(w * 0.85, h * 0.76)
      ..quadraticBezierTo(w * 0.55, h * 0.88, w * 0.6, h)
      ..close();
    canvas.drawPath(pathDraw, Paint()..color = const Color(0xFFF4C664));

    // ── 10. Windmill ─────────────────────────────────────────────────────────
    final double mx = w * 0.3;
    final double my = h * 0.76;

    // Tower body
    final housePath = Path()
      ..moveTo(mx - 18, my)
      ..lineTo(mx + 18, my)
      ..lineTo(mx + 10, my - 60)
      ..lineTo(mx - 10, my - 60)
      ..close();
    canvas.drawPath(housePath, Paint()..color = Colors.white);

    // Little roof
    final roofPath = Path()
      ..moveTo(mx - 12, my - 60)
      ..lineTo(mx + 12, my - 60)
      ..lineTo(mx, my - 72)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = const Color(0xFFDE6451));

    // Windows/Door
    final darkPaint = Paint()..color = const Color(0xFF1F2933);
    canvas.drawRect(Rect.fromLTWH(mx - 5, my - 22, 10, 12), darkPaint);
    canvas.drawRect(Rect.fromLTWH(mx - 4, my - 45, 8, 10), darkPaint);

    // Blades (Now Animated!)
    final double cx = mx;
    final double cy = my - 50;
    canvas.save();
    canvas.translate(cx, cy);

    // We add the rotationAngle to the initial 45 degree (0.785 rad) tilt
    canvas.rotate(0.785 + rotationAngle);

    for (int i = 0; i < 4; i++) {
      canvas.rotate(1.5708); // 90 degrees per blade
      canvas.drawRect(const Rect.fromLTWH(-2, -40, 4, 40), darkPaint);
      canvas.drawRect(const Rect.fromLTWH(2, -38, 12, 30), Paint()..color = const Color(0xFF4A5560));
    }
    canvas.restore();

    // Red center hub for blades
    canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = const Color(0xFFDE6451));

    // ── 11. Bushes & Trees ───────────────────────────────────────────────────
    final bushLight = Paint()..color = const Color(0xFF86B361);
    final bushDark = Paint()..color = const Color(0xFF4A6B32);

    canvas.drawOval(Rect.fromLTWH(w * 0.05, h * 0.75, 30, 50), bushDark);
    canvas.drawOval(Rect.fromLTWH(w * -0.05, h * 0.8, 45, 45), bushLight);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.82, 35, 35), bushDark);
    canvas.drawOval(Rect.fromLTWH(w * 0.4, h * 0.72, 20, 25), bushDark);

    canvas.drawOval(Rect.fromLTWH(w * 0.85, h * 0.65, 30, 70), bushDark);
    canvas.drawOval(Rect.fromLTWH(w * 0.75, h * 0.8, 45, 40), bushLight);
    canvas.drawOval(Rect.fromLTWH(w * 0.9, h * 0.78, 40, 50), bushLight);

    // ── 12. Fade to Cream at Bottom ──────────────────────────────────────────
    final fadePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF86B361).withOpacity(0), const Color(0xFFf4f1e8)],
      ).createShader(Rect.fromLTWH(0, h * 0.68, w, h * 0.32));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.68, w, h * 0.32), fadePaint);
  }

  // Tell Flutter to repaint whenever the rotation angle changes
  @override
  bool shouldRepaint(covariant _LandscapePainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WEATHER DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class _WeatherData {
  final double tempNow;
  final double tempMax;
  final double tempMin;
  final int weatherCode;
  final double humidity;
  final double windSpeed;
  final double precipitation;
  final int uvIndex;
  final List<_HourlyWeather> hourly;
  final DateTime fetchedAt;

  const _WeatherData({
    required this.tempNow,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.uvIndex,
    required this.hourly,
    required this.fetchedAt,
  });
}

class _HourlyWeather {
  final String hour;
  final double temp;
  final int code;
  final double precip;
  const _HourlyWeather(this.hour, this.temp, this.code, this.precip);
}

/// A recommended place shown based on current weather conditions.
class _RecoPlace {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String name;
  final String reason;
  const _RecoPlace({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.name,
    required this.reason,
  });
}

// ── WMO helpers ───────────────────────────────────────────────────────────────
String _wmoDesc(int code) {
  if (code == 0) return '晴天';
  if (code <= 2) return '多雲';
  if (code == 3) return '陰天';
  if (code <= 49) return '有霧';
  if (code <= 59) return '毛毛雨';
  if (code <= 69) return '下雨';
  if (code <= 79) return '下雪';
  if (code <= 84) return '陣雨';
  if (code <= 99) return '雷陣雨';
  return '未知';
}

String _wmoEmoji(int code) {
  if (code == 0) return '☀️';
  if (code <= 2) return '🌤️';
  if (code == 3) return '☁️';
  if (code <= 49) return '🌫️';
  if (code <= 59) return '🌦️';
  if (code <= 69) return '🌧️';
  if (code <= 79) return '❄️';
  if (code <= 84) return '🌦️';
  if (code <= 99) return '⛈️';
  return '🌈';
}

List<Color> _wmoGradient(int code) {
  if (code == 0) return [const Color(0xFFf59e0b), const Color(0xFFfbbf24)];
  if (code <= 2) return [const Color(0xFF60a5fa), const Color(0xFF93c5fd)];
  if (code == 3) return [const Color(0xFF94a3b8), const Color(0xFFcbd5e1)];
  if (code <= 49) return [const Color(0xFF94a3b8), const Color(0xFFcbd5e1)];
  if (code <= 69) return [const Color(0xFF3b82f6), const Color(0xFF60a5fa)];
  if (code <= 99) return [const Color(0xFF6366f1), const Color(0xFF818cf8)];
  return [AppTheme.primaryGreen, const Color(0xFF74c69d)];
}

// ── Weather-based recommendations ─────────────────────────────────────────────
List<_RecoPlace> _getRecommendations(int code, double temp) {
  final isRainy = code >= 50 && code <= 99;
  final isHot   = temp >= 32;
  final isCool  = temp <= 18;

  if (isRainy) {
    return const [
      _RecoPlace(icon: Icons.museum_outlined,     iconColor: Color(0xFF1d4ed8), bgColor: Color(0xFFdbeafe), name: '嘉義市立博物館',  reason: '室內避雨好去處'),
      _RecoPlace(icon: Icons.coffee_outlined,     iconColor: Color(0xFF92400e), bgColor: Color(0xFFfef3c7), name: '文創咖啡街',      reason: '雨天喝咖啡最愜意'),
      _RecoPlace(icon: Icons.restaurant_outlined, iconColor: Color(0xFFea580c), bgColor: Color(0xFFfde8d8), name: '老字號牛肉麵',    reason: '雨天暖心熱湯'),
    ];
  }
  if (isHot) {
    return const [
      _RecoPlace(icon: Icons.water_outlined,      iconColor: Color(0xFF0369a1), bgColor: Color(0xFFe0f2fe), name: '布袋海水浴場',    reason: '消暑戲水首選'),
      _RecoPlace(icon: Icons.ac_unit_outlined,    iconColor: Color(0xFF065f46), bgColor: Color(0xFFd1fae5), name: '火雞肉飯名店',    reason: '室內冷氣必吃'),
      _RecoPlace(icon: Icons.landscape_outlined,  iconColor: Color(0xFF166534), bgColor: Color(0xFFdcfce7), name: '阿里山步道',      reason: '高山涼爽好踏青'),
    ];
  }
  if (isCool) {
    return const [
      _RecoPlace(icon: Icons.terrain_outlined,    iconColor: Color(0xFF166534), bgColor: Color(0xFFd1fae5), name: '阿里山國家風景區', reason: '涼爽好登山'),
      _RecoPlace(icon: Icons.local_cafe_outlined, iconColor: Color(0xFF92400e), bgColor: Color(0xFFfef3c7), name: '嘉義農場品茗',    reason: '冬日茶香最迷人'),
      _RecoPlace(icon: Icons.park_outlined,       iconColor: Color(0xFF166534), bgColor: Color(0xFFdcfce7), name: '植物園散步',      reason: '清涼漫步賞花'),
    ];
  }
  return const [
    _RecoPlace(icon: Icons.train_outlined,        iconColor: Color(0xFF166534), bgColor: Color(0xFFd1fae5), name: '阿里山森林鐵路',  reason: '好天氣絕美景觀'),
    _RecoPlace(icon: Icons.festival_outlined,     iconColor: Color(0xFF7c3aed), bgColor: Color(0xFFede9fe), name: '嘉義文化園區',    reason: '晴天戶外活動'),
    _RecoPlace(icon: Icons.water_outlined,        iconColor: Color(0xFF1d4ed8), bgColor: Color(0xFFdbeafe), name: '蘭潭水庫環湖',    reason: '藍天映湖面超美'),
  ];
}

({String icon, String title, String badge, Color badgeBg, Color badgeText})
_getRecoHeader(int code, double temp) {
  if (code >= 50 && code <= 99) {
    return (
    icon: '🌧️', title: '下雨天推薦去這裡', badge: '室內首選',
    badgeBg: const Color(0xFFdbeafe), badgeText: const Color(0xFF1e40af),
    );
  }
  if (temp >= 32) {
    return (
    icon: '🔥', title: '高溫天推薦去這裡', badge: '避暑首選',
    badgeBg: const Color(0xFFd1fae5), badgeText: const Color(0xFF065f46),
    );
  }
  if (temp <= 18) {
    return (
    icon: '🧊', title: '涼爽天推薦去這裡', badge: '踏青首選',
    badgeBg: const Color(0xFFfef3c7), badgeText: const Color(0xFF92400e),
    );
  }
  return (
  icon: '☀️', title: '好天氣推薦去這裡', badge: '戶外首選',
  badgeBg: const Color(0xFFd1fae5), badgeText: const Color(0xFF065f46),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WEATHER SECTION  (replaces the old _WeatherSection)
// ══════════════════════════════════════════════════════════════════════════════

class _WeatherSection extends StatefulWidget {
  const _WeatherSection();
  @override
  State<_WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<_WeatherSection> {
  _WeatherData? _data;
  bool _loading = true;
  String? _error;

  static const double _lat = 23.4801;
  static const double _lng = 120.4491;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=$_lat&longitude=$_lng'
            '&current=temperature_2m,relative_humidity_2m,weather_code,'
            'wind_speed_10m,precipitation,apparent_temperature'
            '&hourly=temperature_2m,weather_code,precipitation_probability'
            '&daily=temperature_2m_max,temperature_2m_min,uv_index_max'
            '&timezone=Asia%2FTaipei'
            '&forecast_days=1'
            '&wind_speed_unit=kmh',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final j      = json.decode(resp.body) as Map<String, dynamic>;
      final cur    = j['current']  as Map<String, dynamic>;
      final daily  = j['daily']    as Map<String, dynamic>;
      final hourly = j['hourly']   as Map<String, dynamic>;

      final times   = List<String>.from(hourly['time']);
      final temps   = List<double>.from((hourly['temperature_2m'] as List).map((e) => (e as num).toDouble()));
      final codes   = List<int>.from((hourly['weather_code'] as List).map((e) => (e as num).toInt()));
      final precips = List<int>.from((hourly['precipitation_probability'] as List).map((e) => (e as num).toInt()));

      final nowHour = '${now.year}-${_p(now.month)}-${_p(now.day)}T${_p(now.hour)}:00';
      int startIdx = times.indexWhere((t) => t.compareTo(nowHour) >= 0);
      if (startIdx < 0) startIdx = 0;

      final hourlyList = <_HourlyWeather>[];
      for (int i = startIdx; i < startIdx + 6 && i < times.length; i++) {
        hourlyList.add(_HourlyWeather(
          times[i].substring(11, 16),
          temps[i],
          codes[i],
          precips[i].toDouble(),
        ));
      }

      setState(() {
        _data = _WeatherData(
          tempNow:       (cur['temperature_2m']       as num).toDouble(),
          humidity:      (cur['relative_humidity_2m'] as num).toDouble(),
          weatherCode:   (cur['weather_code']         as num).toInt(),
          windSpeed:     (cur['wind_speed_10m']       as num).toDouble(),
          precipitation: (cur['precipitation']        as num).toDouble(),
          tempMax:       ((daily['temperature_2m_max'] as List).first as num).toDouble(),
          tempMin:       ((daily['temperature_2m_min'] as List).first as num).toDouble(),
          uvIndex:       ((daily['uv_index_max']       as List).first as num).toInt(),
          hourly:        hourlyList,
          fetchedAt:     now,
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('今日天氣',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const Spacer(),
          GestureDetector(
            onTap: _fetch,
            child: Row(children: [
              const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textGrey),
              const SizedBox(width: 3),
              Text(
                _data != null
                    ? '${_data!.fetchedAt.hour}:${_p(_data!.fetchedAt.minute)} 更新'
                    : '嘉義市',
                style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (_loading)        _buildSkeleton()
        else if (_error != null) _buildError()
        else if (_data != null)  _buildCard(_data!),
      ]),
    );
  }

  Widget _buildSkeleton() => Container(
    height: 160,
    decoration: BoxDecoration(
        color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
    child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
  );

  Widget _buildError() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.red.shade100),
    ),
    child: Row(children: [
      Icon(Icons.cloud_off, color: Colors.red.shade300, size: 28),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('無法取得天氣資料', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('請確認網路連線', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
      ])),
      TextButton(onPressed: _fetch, child: const Text('重試')),
    ]),
  );

  Widget _buildCard(_WeatherData d) {
    final grad  = _wmoGradient(d.weatherCode);
    final emoji = _wmoEmoji(d.weatherCode);
    final desc  = _wmoDesc(d.weatherCode);
    final recos = _getRecommendations(d.weatherCode, d.tempNow);
    final hdr   = _getRecoHeader(d.weatherCode, d.tempNow);

    return Column(children: [
      // ── Main weather card ────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grad,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: grad[0].withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(children: [
          // Temperature row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${d.tempNow.round()}',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w200, color: Colors.white, height: 1)),
                const Text('°C',
                    style: TextStyle(fontSize: 20, color: Colors.white70, height: 2.4)),
              ]),
              Text(desc, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)),
              Text('最高 ${d.tempMax.round()}° · 最低 ${d.tempMin.round()}°',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 4),
              const Row(children: [
                Icon(Icons.location_on, size: 12, color: Colors.white70),
                SizedBox(width: 2),
                Text('嘉義市', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ]),
          ]),
          const SizedBox(height: 12),
          // Detail chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DetailChip(Icons.water_drop_outlined,  '${d.humidity.round()}%',      '濕度'),
                _DetailChip(Icons.air,                  '${d.windSpeed.round()} km/h', '風速'),
                _DetailChip(Icons.umbrella_outlined,    '${d.precipitation} mm',       '降雨'),
                _DetailChip(Icons.wb_sunny_outlined,    'UV ${d.uvIndex}',             '紫外線'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hourly forecast
          if (d.hourly.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: d.hourly.map((h) => _HourlyChip(h)).toList(),
            ),
        ]),
      ),

      // ── Weather Recommendation Panel ─────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [BoxShadow(color: grad[0].withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(children: [
            Text(hdr.icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(hdr.title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hdr.badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(hdr.badge,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: hdr.badgeText)),
            ),
          ]),
          const SizedBox(height: 12),
          // Horizontally scrollable place cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: recos.map((p) => _RecoPlaceCard(place: p)).toList(),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ── Recommendation Place Card ─────────────────────────────────────────────────
class _RecoPlaceCard extends StatelessWidget {
  final _RecoPlace place;
  const _RecoPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppTheme.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: place.iconColor.withOpacity(0.18), width: 1.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon area
        Container(
          height: 58,
          color: place.bgColor,
          child: Center(
            child: Icon(place.icon, color: place.iconColor, size: 28),
          ),
        ),
        // Text area
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textDark),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(place.reason,
                style: const TextStyle(fontSize: 9.5, color: AppTheme.textGrey, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

// ── Detail / Hourly chips (unchanged) ────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _DetailChip(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: Colors.white),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ]);
  }
}

class _HourlyChip extends StatelessWidget {
  final _HourlyWeather h;
  const _HourlyChip(this.h);
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(h.hour, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      const SizedBox(height: 3),
      Text(_wmoEmoji(h.code), style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 2),
      Text('${h.temp.round()}°', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
      if (h.precip > 0)
        Text('${h.precip.round()}%', style: const TextStyle(fontSize: 9, color: Colors.white60)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ALL UNCHANGED CLASSES BELOW
// ══════════════════════════════════════════════════════════════════════════════

class _EventsBannerCarousel extends StatefulWidget {
  final List<String> banners;
  final List<String> titles;
  final List<String> subs;
  final List<String> links;
  const _EventsBannerCarousel({
    required this.banners,
    required this.titles,
    required this.subs,
    required this.links,
  });
  @override
  State<_EventsBannerCarousel> createState() => _EventsBannerCarouselState();
}

class _EventsBannerCarouselState extends State<_EventsBannerCarousel> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('最新消息',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(widget.links[i]);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(widget.banners[i], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AppTheme.primaryGreen)),
                    Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.65)]))),
                    Positioned(
                        bottom: 16, left: 16, right: 16,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.titles[i],
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          Text(widget.subs[i],
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                        ])),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryGreen : AppTheme.primaryGreen.withOpacity(0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _FavoriteMapPreview extends StatefulWidget {
  final Set<String> favoriteIds;
  const _FavoriteMapPreview({required this.favoriteIds});
  @override
  State<_FavoriteMapPreview> createState() => _FavoriteMapPreviewState();
}

class _FavoriteMapPreviewState extends State<_FavoriteMapPreview> {
  late Future<List<PlaceModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadFavorites(widget.favoriteIds);
  }

  @override
  void didUpdateWidget(_FavoriteMapPreview old) {
    super.didUpdateWidget(old);
    if (old.favoriteIds != widget.favoriteIds) {
      _future = _loadFavorites(widget.favoriteIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.favoriteIds.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.15)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.favorite_border, size: 36, color: AppTheme.primaryGreen.withOpacity(0.4)),
          const SizedBox(height: 10),
          const Text('尚未收藏任何地標', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('收藏景點後會在此顯示', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ]),
      );
    }

    return FutureBuilder<List<PlaceModel>>(
      future: _future,
      builder: (_, snap) {
        final places = snap.data ?? [];
        final valid  = places.where((p) => p.lat != null && p.lng != null).toList();

        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          );
        }
        if (valid.isEmpty) {
          return Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('收藏的地標無地圖資訊', style: TextStyle(color: AppTheme.textGrey))),
          );
        }

        final center = LatLng(
          valid.map((p) => p.lat!).reduce((a, b) => a + b) / valid.length,
          valid.map((p) => p.lng!).reduce((a, b) => a + b) / valid.length,
        );

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => FavoritesMapPage(places: valid))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: Stack(children: [
                fmap.FlutterMap(
                  options: fmap.MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    interactionOptions: const fmap.InteractionOptions(flags: fmap.InteractiveFlag.none),
                  ),
                  children: [
                    fmap.TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.chiayiApp',
                    ),
                    fmap.MarkerLayer(
                      markers: valid.map((p) => fmap.Marker(
                        point: LatLng(p.lat!, p.lng!),
                        width: 32, height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6)],
                          ),
                          child: const Icon(Icons.favorite, color: Colors.white, size: 14),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                    ),
                  ),
                ),
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 12)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.map, color: Colors.white, size: 15),
                    SizedBox(width: 7),
                    Text('查看收藏地圖',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                )),
                Positioned(
                  top: 10, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.93),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.favorite, size: 12, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('${valid.length} 個收藏地點',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Future<List<PlaceModel>> _loadFavorites(Set<String> ids) async {
    final svc = FirestoreService();
    final results = <PlaceModel>[];
    for (final id in ids) {
      final p = await svc.getPlaceById(id);
      if (p != null) results.add(p);
    }
    return results;
  }
}

class FavoritesMapPage extends StatefulWidget {
  final List<PlaceModel> places;
  const FavoritesMapPage({super.key, required this.places});
  @override
  State<FavoritesMapPage> createState() => _FavoritesMapPageState();
}

class _FavoritesMapPageState extends State<FavoritesMapPage> with TickerProviderStateMixin {
  final _mapCtrl = fmap.MapController();
  PlaceModel? _sel;

  LatLng get _center => widget.places.isEmpty
      ? const LatLng(23.4801, 120.4491)
      : LatLng(
    widget.places.map((p) => p.lat!).reduce((a, b) => a + b) / widget.places.length,
    widget.places.map((p) => p.lng!).reduce((a, b) => a + b) / widget.places.length,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        fmap.FlutterMap(
          mapController: _mapCtrl,
          options: fmap.MapOptions(
            initialCenter: _center,
            initialZoom: 13,
            onTap: (_, __) => setState(() => _sel = null),
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.chiayiApp',
            ),
            fmap.MarkerLayer(
              markers: widget.places.map((p) => fmap.Marker(
                point: LatLng(p.lat!, p.lng!),
                width: 44, height: 44,
                child: GestureDetector(
                  onTap: () => setState(() => _sel = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _sel?.id == p.id ? Colors.red.shade600 : Colors.red.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: _sel?.id == p.id ? 3 : 2),
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 20),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(
                height: 42,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.favorite, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text('我的收藏地圖', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Text('${widget.places.length}處',
                        style: TextStyle(color: Colors.red.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              )),
            ]),
          ),
        ),
        if (_sel != null)
          Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomSheet(
                  place: _sel!,
                  onClose: () => setState(() => _sel = null),
                  onDetail: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DetailPage(place: _sel!))))),
      ]),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final PlaceModel place;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  const _BottomSheet({required this.place, required this.onClose, required this.onDetail});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildImage(place.imageUrl)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(place.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Icon(Icons.close, size: 20, color: AppTheme.textGrey),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text(place.description,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textGrey, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onDetail,
              child: const Text('查看景點詳情', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) return _placeholder();
    return Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(
    width: 80, height: 80,
    color: AppTheme.primaryGreen.withOpacity(0.1),
    child: const Icon(Icons.landscape, color: AppTheme.primaryGreen, size: 30),
  );
}

// ── Quick category data model ─────────────────────────────────────────────────
class _QuickCat {
  final String category;
  final String label;
  final String imagePath;
  final Color color;
  final Color bgColor;
  const _QuickCat(this.category, this.label, this.imagePath, this.color, this.bgColor);
}

// ── Quick category tile widget ────────────────────────────────────────────────
class _QuickCatTile extends StatelessWidget {
  final _QuickCat cat;
  final bool large;
  const _QuickCatTile({required this.cat, this.large = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (cat.category == 'transport') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportPage()));
          return;
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => CategoryListPage(category: cat.category, title: cat.label)));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cat.color.withOpacity(0.15), width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
            fit: StackFit.expand,
            children: [
              // Full image background
              Image.asset(
                cat.imagePath,
                fit: BoxFit.fill,
              ),
              // Dark gradient at bottom
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  color: Colors.black.withOpacity(0.2),
                  child: Text(
                    cat.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ]),
      ),
    );
  }
}