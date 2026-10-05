// lib/pages/category_list_page.dart
//
// 類別條列式搜尋頁
// 快速探索點類別後導入此頁，可搜尋關鍵字並以卡片條列式呈現

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firestore_service.dart';
import '../services/favorites_service.dart';
import 'detail_page.dart';

// ─── 類別對應設定 ────────────────────────────────────────────────────────────
class _CatConfig {
  final String label;
  final IconData icon;
  final Color color;
  const _CatConfig(this.label, this.icon, this.color);
}

const _catConfigs = <String, _CatConfig>{
  'attraction': _CatConfig('景點',   Icons.landscape,          Color(0xFF3DAA6D)),
  'restaurant': _CatConfig('餐廳',   Icons.restaurant,         Color(0xFFEA580C)),
  'hotel':      _CatConfig('住宿',   Icons.hotel,              Color(0xFF2563EB)),
  'event':      _CatConfig('活動',   Icons.event,              Color(0xFF7C3AED)),
  'transport':  _CatConfig('交通站', Icons.directions_bus,     Color(0xFF0D9488)),
  // 子類別
  'attraction_culture': _CatConfig('文化古蹟', Icons.account_balance,        Color(0xFF3DAA6D)),
  'attraction_temple':  _CatConfig('廟宇寺院', Icons.temple_buddhist,        Color(0xFF3DAA6D)),
  'attraction_park':    _CatConfig('公園',    Icons.nature_people,           Color(0xFF3DAA6D)),
  'attraction_museum':  _CatConfig('博物館',  Icons.museum,                  Color(0xFF3DAA6D)),
  'restaurant_cafe':    _CatConfig('咖啡廳',  Icons.coffee,                  Color(0xFFEA580C)),
  'restaurant_dessert': _CatConfig('甜點',    Icons.icecream,                Color(0xFFEA580C)),
  'transport_train':    _CatConfig('火車站',  Icons.train,                   Color(0xFF0D9488)),
  'transport_bus':      _CatConfig('公車站',  Icons.directions_bus_filled,   Color(0xFF0D9488)),
  'transport_bike':     _CatConfig('單車租借', Icons.pedal_bike,             Color(0xFF0D9488)),
};

_CatConfig _cfg(String cat) =>
    _catConfigs[cat] ?? const _CatConfig('地點', Icons.place, Color(0xFF3DAA6D));

// ─────────────────────────────────────────────────────────────────────────────
// CategoryListPage
// ─────────────────────────────────────────────────────────────────────────────
class CategoryListPage extends StatefulWidget {
  final String category;
  final String title;

  const CategoryListPage({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<PlaceModel> _all      = [];
  List<PlaceModel> _filtered = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = FirestoreService();
      List<PlaceModel> data;
      switch (widget.category) {
        case 'restaurant':
          data = await svc.getRestaurants();
          break;
        case 'hotel':
          data = await svc.getHotels();
          break;
        case 'event':
          data = await svc.getEvents();
          break;
        case 'transport':
          data = await svc.getTransportStops();
          break;
        default:
          data = await svc.getPlaces(category: widget.category);
      }
      _all = data;
      _applyFilter(_query);
    } catch (e) {
      debugPrint('[CategoryListPage] 載入失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String q) {
    setState(() {
      _query = q;
      _filtered = q.isEmpty
          ? List.from(_all)
          : _all.where((p) {
        final lower = q.toLowerCase();
        return p.name.toLowerCase().contains(lower) ||
            p.location.toLowerCase().contains(lower) ||
            p.tags.any((t) => t.toLowerCase().contains(lower));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(widget.category);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: _buildAppBar(cfg),
      body: Column(
        children: [
          _buildSearchBar(cfg),
          _buildResultCount(),
          Expanded(child: _buildList(cfg)),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  AppBar _buildAppBar(_CatConfig cfg) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: AppTheme.textDark,
      title: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: cfg.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(cfg.icon, size: 18, color: cfg.color),
        ),
        const SizedBox(width: 10),
        Text(widget.title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppTheme.textDark)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryGreen),
          tooltip: '重新整理',
          onPressed: _load,
        ),
      ],
    );
  }

  // ── 搜尋列 ──────────────────────────────────────────────────────────────────
  Widget _buildSearchBar(_CatConfig cfg) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _applyFilter,
        style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
        decoration: InputDecoration(
          hintText: '搜尋${widget.title}名稱、地址或標籤…',
          hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: cfg.color, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textGrey),
            onPressed: () {
              _searchCtrl.clear();
              _applyFilter('');
            },
          )
              : null,
          filled: true,
          fillColor: AppTheme.cream,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── 結果數 ──────────────────────────────────────────────────────────────────
  Widget _buildResultCount() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        Text(
          _loading
              ? '載入中…'
              : _query.isEmpty
              ? '共 ${_filtered.length} 筆'
              : '「$_query」共 ${_filtered.length} 筆',
          style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
        ),
      ]),
    );
  }

  // ── 清單主體 ────────────────────────────────────────────────────────────────
  Widget _buildList(_CatConfig cfg) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }

    if (_filtered.isEmpty) {
      return _EmptyState(
        cfg: cfg,
        query: _query,
        onClear: () { _searchCtrl.clear(); _applyFilter(''); },
        onRefresh: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryGreen,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _PlaceListCard(
          place: _filtered[i],
          cfg: cfg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 清單卡片
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceListCard extends StatelessWidget {
  final PlaceModel place;
  final _CatConfig cfg;
  const _PlaceListCard({required this.place, required this.cfg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailPage(place: place)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 縮圖
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: CachedNetworkImage(
                imageUrl: place.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 100,
                  color: cfg.color.withOpacity(0.1),
                  child: Icon(cfg.icon,
                      color: cfg.color.withOpacity(0.4), size: 28),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 100,
                  color: cfg.color.withOpacity(0.1),
                  child: Icon(cfg.icon,
                      color: cfg.color.withOpacity(0.4), size: 28),
                ),
              ),
            ),

            // 內容
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名稱 + 收藏
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Consumer<FavoritesService>(
                          builder: (_, fav, __) => GestureDetector(
                            onTap: () => fav.toggle(place.id),
                            child: Icon(
                              fav.isFavorite(place.id)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: fav.isFavorite(place.id)
                                  ? Colors.red
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 地址
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: cfg.color),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          place.location,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // 評分 + 標籤
                    Row(children: [
                      if (place.category != 'event') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 11, color: AppTheme.amber),
                              const SizedBox(width: 2),
                              Text(place.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.amber)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: cfg.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(cfg.label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cfg.color)),
                      ),
                      const SizedBox(width: 6),
                      if (place.tags.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            place.tags.first,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textGrey),
                          ),
                        ),
                    ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// 空狀態
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _CatConfig cfg;
  final String query;
  final VoidCallback onClear;
  final VoidCallback onRefresh;
  const _EmptyState({
    required this.cfg,
    required this.query,
    required this.onClear,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(cfg.icon, size: 56, color: cfg.color.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? '暫無資料' : '找不到「$query」',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty ? '目前沒有${cfg.label}資料' : '請嘗試其他關鍵字',
              style: const TextStyle(
                  color: AppTheme.textGrey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (query.isNotEmpty)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear,
                    size: 16, color: AppTheme.primaryGreen),
                label: const Text('清除搜尋',
                    style: TextStyle(color: AppTheme.primaryGreen)),
              )
            else
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重新整理'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen),
              ),
          ],
        ),
      ),
    );
  }
}