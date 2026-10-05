// lib/pages/map_page.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firestore_service.dart';
import '../services/favorites_service.dart';
import '../widgets/transport_bottom_sheet.dart';
import 'detail_page.dart';
import '../services/transport_service.dart';

const _kCenter = LatLng(23.4801, 120.4491);

// ── Helper: normalise sub-category to parent for colour/icon lookup ───────────
String _parentCat(String c) {
  if (c.startsWith('restaurant')) return 'restaurant';
  if (c.startsWith('transport'))  return 'transport';
  if (c.startsWith('attraction')) return 'attraction';
  if (c.startsWith('hotel'))      return 'hotel';
  return c;
}

// ── Per-sub-category colours ──────────────────────────────────────────────────
Color catColor(String cat) {
  switch (cat) {
    case 'restaurant':             return const Color(0xFFFDAE44);
    case 'restaurant_cafe':        return const Color(0xFFED9121);
    case 'restaurant_dessert':     return const Color(0xFFD16002);
    case 'hotel':                  return const Color(0xFF023E83);
    case 'event':                  return const Color(0xFF7C3AED);
    case 'transport_bike':         return const Color(0xFF16A34A);
    case 'transport_train':        return const Color(0xFFDC2626);
    case 'transport':
    case 'transport_bus':          return const Color(0xFF1D4ED8);
    default:                       return AppTheme.primaryGreen;
  }
}

IconData catIcon(String cat) {
  switch (cat) {
    case 'restaurant':             return Icons.restaurant;
    case 'restaurant_cafe':        return Icons.coffee;
    case 'restaurant_dessert':     return Icons.icecream;
    case 'hotel':                  return Icons.hotel;
    case 'event':                  return Icons.event;
    case 'transport_bike':         return Icons.pedal_bike_rounded;
    case 'transport_train':        return Icons.train;
    case 'transport':
    case 'transport_bus':          return Icons.directions_bus_rounded;
    default:                       return Icons.landscape;
  }
}

const _catLabel = {
  'attraction': '景點', 'restaurant': '餐廳',
  'hotel': '住宿', 'event': '活動',
  'transport': '交通', 'transport_bus': '公車站', 'transport_bike': 'YouBike',
  'transport_train': '火車站', 'restaurant_cafe': '咖啡廳',
  'restaurant_dessert': '甜點', 'attraction_park': '公園', 'attraction_museum': '博物館',
};

// ── Distance helper ───────────────────────────────────────────────────────────
double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

// ── Navigation helper ─────────────────────────────────────────────────────────
Future<void> _openNavigation(PlaceModel place, Position? userPos) async {
  final lat = place.lat!;
  final lng = place.lng!;
  final origin = userPos != null
      ? '${userPos.latitude},${userPos.longitude}'
      : '';

  final googleUrl = origin.isNotEmpty
      ? 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$lat,$lng&travelmode=driving'
      : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  try {
    await launchUrl(Uri.parse(googleUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng&zoom=17'),
      mode: LaunchMode.externalApplication,
    );
  }
}

// ── Category models ───────────────────────────────────────────────────────────
class _SubCategory {
  final String id;
  final String label;
  final IconData icon;
  const _SubCategory(this.id, this.label, this.icon);
}

class _CategoryGroup {
  final String label;
  final Color color;
  final List<_SubCategory> subs;
  const _CategoryGroup(this.label, this.color, this.subs);
}

const _groups = [
  _CategoryGroup('景點', AppTheme.primaryGreen, [
    _SubCategory('attraction',        '景點',    Icons.landscape),
    _SubCategory('attraction_nature', '自然風景', Icons.park),
    _SubCategory('attraction_park',   '公園',    Icons.nature_people),
    _SubCategory('attraction_museum', '博物館',   Icons.museum),
  ]),
  _CategoryGroup('交通', Color(0xFF0D9488), [
    _SubCategory('transport',       '交通站點',          Icons.directions_bus),
    _SubCategory('transport_train', '火車站',            Icons.train),
    _SubCategory('transport_bus',   '公車站',            Icons.directions_bus_filled),
    _SubCategory('transport_bike',  'YouBike',           Icons.pedal_bike),
  ]),
  _CategoryGroup('餐飲', Color(0xFFEA580C), [
    _SubCategory('restaurant',          '餐廳',  Icons.restaurant),
    _SubCategory('restaurant_cafe',     '咖啡廳', Icons.coffee),
    _SubCategory('restaurant_dessert',  '甜點',  Icons.icecream),
  ]),
];

const _quickFilters = [
  _SubCategory('attraction', '景點',  Icons.landscape),
  _SubCategory('hotel',      '住宿',  Icons.hotel),
  _SubCategory('transport',  '交通',  Icons.directions_bus),
  _SubCategory('restaurant', '餐廳',  Icons.restaurant),
];

// ─────────────────────────────────────────────────────────────────────────────
// CategoryMapPage
// ─────────────────────────────────────────────────────────────────────────────
class CategoryMapPage extends StatefulWidget {
  final String category;
  final String title;
  const CategoryMapPage({super.key, required this.category, required this.title});
  @override
  State<CategoryMapPage> createState() => _CategoryMapPageState();
}

class _CategoryMapPageState extends State<CategoryMapPage> with TickerProviderStateMixin {
  final _mapCtrl = MapController();
  List<PlaceModel> _all      = [];
  List<PlaceModel> _filtered = [];
  bool        _loading   = true;
  PlaceModel? _sel;
  int         _tile      = 0;
  final _searchCtrl = TextEditingController();
  bool   _showSearch = false;
  String _query      = '';

  late String _activeCategory;
  late String _activeTitle;

  // ── Location state ──────────────────────────────────────────────────────────
  Position?               _userPos;
  bool                    _locLoading    = false;
  bool                    _locDenied     = false;
  StreamSubscription<Position>? _locSub;

  static const _tiles = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ];
  static const _tileIcons = [Icons.map, Icons.terrain, Icons.satellite_alt];

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.category;
    _activeTitle    = widget.title;
    _load(_activeCategory);
    _startLocation();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────────────────────
  Future<void> _startLocation() async {
    setState(() => _locLoading = true);

    // Check & request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (mounted) setState(() { _locLoading = false; _locDenied = true; });
      return;
    }

    // Check service enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() { _locLoading = false; _locDenied = true; });
      return;
    }

    // Get initial position
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) setState(() { _userPos = pos; _locLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _locLoading = false);
    }

    // Stream live updates
    _locSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 metres
      ),
    ).listen((pos) {
      if (mounted) setState(() => _userPos = pos);
    });
  }

  void _flyToUser() {
    if (_userPos == null) {
      if (_locDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('位置權限已被拒絕，請在設定中開啟')),
        );
      }
      return;
    }
    _flyTo(LatLng(_userPos!.latitude, _userPos!.longitude), zoom: 16);
  }

  // ── Data loading ────────────────────────────────────────────────────────────
  Future<void> _load(String cat) async {
    setState(() { _loading = true; _sel = null; });
    final svc = FirestoreService();
    final tdx = TransportService();
    List<PlaceModel> data;

    switch (cat) {
      case 'restaurant':
      case 'restaurant_cafe':
      case 'restaurant_dessert':
        final allRestaurants = await svc.getRestaurants();
        data = cat == 'restaurant'
            ? allRestaurants
            : allRestaurants.where((p) => p.category == cat).toList();
        break;

      case 'event':
        data = await svc.getEvents();
        break;

      case 'hotel':
        data = await svc.getHotels();
        break;

      case 'transport':
      case 'transport_bus':
        final stops = await tdx.getBusStops();
        data = stops.map((s) => PlaceModel(
          id: s.stopUID, name: s.stopName, category: 'transport_bus',
          location: s.address, lat: s.lat, lng: s.lng,
          imageUrl: '', tags: ['bus'], description: '',
        )).toList();
        break;

      case 'transport_bike':
        final stations = await tdx.getYouBikeStations();
        data = stations.map((s) => PlaceModel(
          id: s.stationId, name: s.stationName, category: 'transport_bike',
          location: s.address, lat: s.lat, lng: s.lng, imageUrl: '',
          tags: ['bike', '${s.availableBikes}', '${s.availableSpaces}', '${s.totalSpaces}'],
          description: '可借 ${s.availableBikes} 輛・可還 ${s.availableSpaces} 格',
        )).toList();
        break;

      case 'transport_train':
        data = [PlaceModel(
          id: 'chiayi_train_station', name: '嘉義火車站',
          category: 'transport_train', location: '嘉義市東區中山路528號',
          lat: 23.4789, lng: 120.4409, imageUrl: '',
          tags: ['train'], description: '台鐵嘉義站',
        )];
        break;

      default:
        data = await svc.getPlaces(category: cat);
    }

    _all      = data.where((p) => p.lat != null && p.lng != null).toList();
    _filtered = _sortByDistance(List.from(_all));
    if (mounted) setState(() => _loading = false);
  }

  // Sort places by distance from user if location is available
  List<PlaceModel> _sortByDistance(List<PlaceModel> places) {
    if (_userPos == null) return places;
    places.sort((a, b) {
      final da = _distanceMeters(_userPos!.latitude, _userPos!.longitude, a.lat!, a.lng!);
      final db = _distanceMeters(_userPos!.latitude, _userPos!.longitude, b.lat!, b.lng!);
      return da.compareTo(db);
    });
    return places;
  }

  void _switchCategory(String catId, String label) {
    if (_activeCategory == catId) return;
    setState(() {
      _activeCategory = catId;
      _activeTitle    = label;
      _query          = '';
      _searchCtrl.clear();
      _showSearch     = false;
    });
    _load(catId);
  }

  void _applySearch(String q) {
    setState(() {
      _query = q;
      final base = q.isEmpty
          ? List<PlaceModel>.from(_all)
          : _all.where((p) =>
      p.name.contains(q) || p.location.contains(q) ||
          p.tags.any((t) => t.contains(q))).toList();
      _filtered = _sortByDistance(base);
      _sel = null;
    });
  }

  void _flyTo(LatLng pt, {double zoom = 15}) {
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    final from = _mapCtrl.camera.center;
    final latT = Tween(begin: from.latitude,  end: pt.latitude);
    final lngT = Tween(begin: from.longitude, end: pt.longitude);
    final zT   = Tween(begin: _mapCtrl.camera.zoom, end: zoom);
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOutCubic);
    ctrl.addListener(() =>
        _mapCtrl.move(LatLng(latT.evaluate(anim), lngT.evaluate(anim)), zT.evaluate(anim)));
    ctrl.addStatusListener((s) { if (s == AnimationStatus.completed) ctrl.dispose(); });
    ctrl.forward();
  }

  LatLng get _center {
    if (_filtered.isEmpty) return _kCenter;
    final lat = _filtered.map((p) => p.lat!).reduce((a, b) => a + b) / _filtered.length;
    final lng = _filtered.map((p) => p.lng!).reduce((a, b) => a + b) / _filtered.length;
    return LatLng(lat, lng);
  }

  void _openMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreCategoriesSheet(
        activeCategory: _activeCategory,
        onSelect: (sub) {
          Navigator.pop(context);
          _switchCategory(sub.id, sub.label);
        },
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final col = catColor(_parentCat(_activeCategory));
    final ico = catIcon(_parentCat(_activeCategory));

    return Scaffold(
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _kCenter,
            initialZoom: 12.5,
            minZoom: 8,
            maxZoom: 18,
            onTap: (_, __) => setState(() { _sel = null; _showSearch = false; }),
          ),
          children: [
            TileLayer(
              urlTemplate: _tiles[_tile],
              userAgentPackageName: 'com.example.chiayiApp',
              subdomains: _tile == 1 ? const ['a', 'b', 'c'] : const [],
            ),

            // ── Place markers ───────────────────────────────────────────────
            if (!_loading)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 50,
                  size: const Size(40, 40),
                  markers: _filtered.map((p) {
                    final pCol       = catColor(p.category);
                    final pIco       = catIcon(p.category);
                    final isBike     = p.category == 'transport_bike';
                    final badge      = isBike && p.tags.length > 1 ? p.tags[1] : null;
                    final badgeCount = int.tryParse(badge ?? '') ?? 0;
                    final pinCol     = isBike
                        ? (badgeCount == 0 ? Colors.red.shade600
                        : badgeCount <= 2 ? Colors.orange.shade600 : pCol)
                        : pCol;
                    return Marker(
                      point: LatLng(p.lat!, p.lng!),
                      width: isBike ? 46 : 44,
                      height: isBike ? 46 : 44,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _sel = p);
                          _flyTo(LatLng(p.lat!, p.lng!));
                        },
                        child: _MarkerPin(
                          color: pinCol, icon: pIco,
                          selected: _sel?.id == p.id, badge: badge,
                        ),
                      ),
                    );
                  }).toList(),
                  builder: (_, m) => Container(
                    decoration: BoxDecoration(
                      color: col, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: col.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: Center(child: Text('${m.length}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  ),
                ),
              ),

            // ── Live location blue dot ───────────────────────────────────────
            if (_userPos != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(_userPos!.latitude, _userPos!.longitude),
                    width: 24,
                    height: 24,
                    child: _LiveDot(),
                  ),
                ],
              ),
          ],
        ),

        // ── Top UI ───────────────────────────────────────────────────────────
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Icon(ico, size: 16, color: col),
                    const SizedBox(width: 7),
                    Text(_activeTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text('${_filtered.length}處',
                          style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
                const Spacer(),
                _PillBtn(
                  icon: _showSearch ? Icons.close : Icons.search,
                  onTap: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) { _searchCtrl.clear(); _applySearch(''); }
                  }),
                ),
                const SizedBox(width: 8),
                _PillBtn(
                  icon: _tileIcons[_tile],
                  onTap: () => setState(() => _tile = (_tile + 1) % 3),
                ),
              ]),
            ),

            // Filter chips
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ..._quickFilters.map((f) {
                    final active = _activeCategory == f.id ||
                        _groups.any((g) =>
                            g.subs.any((s) => s.id == _activeCategory && s.id == f.id));
                    final chipColor = catColor(f.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _switchCategory(f.id, f.label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          decoration: BoxDecoration(
                            color: active ? chipColor : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: active ? chipColor : Colors.grey.shade300, width: 1),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(f.icon, size: 14, color: active ? Colors.white : chipColor),
                            const SizedBox(width: 5),
                            Text(f.label,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: active ? Colors.white : AppTheme.textDark,
                                )),
                          ]),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _openMoreSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('更多',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: AppTheme.textDark)),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: Colors.grey.shade600),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _applySearch,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '搜尋${_activeTitle}名稱或地址...',
                      hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: col, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
          ]),
        ),

        // ── Loading overlay ───────────────────────────────────────────────────
        if (_loading)
          Container(
              color: Colors.black26,
              child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen))),

        // ── Empty state ───────────────────────────────────────────────────────
        if (!_loading && _filtered.isEmpty)
          Center(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ico, size: 48, color: col.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(_query.isEmpty ? '暫無${_activeTitle}資料' : '找不到「$_query」',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 15)),
              if (_query.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                    onPressed: () { _searchCtrl.clear(); _applySearch(''); },
                    child: const Text('清除搜尋')),
              ],
            ]),
          )),

        // ── Bottom strip ──────────────────────────────────────────────────────
        if (!_loading && _sel == null && _filtered.isNotEmpty)
          Positioned(
              bottom: 0, left: 0, right: 0,
              child: _PlaceStrip(
                  places: _filtered,
                  selectedId: null,
                  userPos: _userPos,
                  onTap: (p) {
                    setState(() => _sel = p);
                    _flyTo(LatLng(p.lat!, p.lng!));
                  })),

        // ── Bottom detail sheet ───────────────────────────────────────────────
        if (_sel != null)
          Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomSheet(
                  place: _sel!,
                  userPos: _userPos,
                  onClose: () => setState(() => _sel = null),
                  onDetail: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => DetailPage(place: _sel!))))),
      ]),

      // ── FABs ─────────────────────────────────────────────────────────────────
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        // Live location button
        FloatingActionButton.small(
            heroTag: 'loc',
            backgroundColor: _userPos != null ? AppTheme.primaryGreen : Colors.white,
            elevation: 3,
            onPressed: _flyToUser,
            child: _locLoading
                ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                : Icon(
                Icons.my_location,
                color: _userPos != null ? Colors.white : AppTheme.primaryGreen,
                size: 20)),
        const SizedBox(height: 8),
        FloatingActionButton.small(
            heroTag: 'ct', backgroundColor: Colors.white, elevation: 3,
            onPressed: () => _flyTo(_center, zoom: 12.5),
            child: const Icon(Icons.center_focus_strong, color: AppTheme.primaryGreen, size: 20)),
        const SizedBox(height: 8),
        FloatingActionButton.small(
            heroTag: 'zi', backgroundColor: Colors.white, elevation: 3,
            onPressed: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom + 1),
            child: const Icon(Icons.add, color: AppTheme.textDark, size: 20)),
        const SizedBox(height: 4),
        FloatingActionButton.small(
            heroTag: 'zo', backgroundColor: Colors.white, elevation: 3,
            onPressed: () => _mapCtrl.move(_mapCtrl.camera.center, _mapCtrl.camera.zoom - 1),
            child: const Icon(Icons.remove, color: AppTheme.textDark, size: 20)),
      ]),
    );
  }
}

// ── Live location blue dot ────────────────────────────────────────────────────
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _pulse = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        // Pulsing ring
        Container(
          width: 24 * _pulse.value,
          height: 24 * _pulse.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.2 * (1 - _pulse.value + 0.5)),
          ),
        ),
        // Solid blue dot
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade600,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(
                color: Colors.blue.withOpacity(0.4), blurRadius: 6)],
          ),
        ),
      ]),
    );
  }
}

// ── "更多類別" Bottom Sheet ────────────────────────────────────────────────────
class _MoreCategoriesSheet extends StatefulWidget {
  final String activeCategory;
  final void Function(_SubCategory) onSelect;
  const _MoreCategoriesSheet({required this.activeCategory, required this.onSelect});
  @override
  State<_MoreCategoriesSheet> createState() => _MoreCategoriesSheetState();
}

class _MoreCategoriesSheetState extends State<_MoreCategoriesSheet> {
  late int _groupIdx;

  @override
  void initState() {
    super.initState();
    _groupIdx = _groups.indexWhere(
            (g) => g.subs.any((s) => s.id == widget.activeCategory));
    if (_groupIdx < 0) _groupIdx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final group = _groups[_groupIdx];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(children: [
              const Text('更多類別',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const Spacer(),
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppTheme.textGrey)),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: List.generate(_groups.length, (i) {
              final g   = _groups[i];
              final sel = i == _groupIdx;
              return GestureDetector(
                onTap: () => setState(() => _groupIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? g.color.withOpacity(0.12) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? g.color : Colors.transparent, width: 1.5),
                  ),
                  child: Text(g.label,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: sel ? g.color : AppTheme.textGrey,
                      )),
                ),
              );
            })),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Wrap(
              spacing: 10, runSpacing: 10,
              children: group.subs.map((sub) {
                final active = sub.id == widget.activeCategory;
                return GestureDetector(
                  onTap: () => widget.onSelect(sub),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? group.color.withOpacity(0.12) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: active ? group.color : Colors.transparent, width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(sub.icon, size: 16,
                          color: active ? group.color : AppTheme.textGrey),
                      const SizedBox(width: 7),
                      Text(sub.label,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500,
                            color: active ? group.color : AppTheme.textDark,
                          )),
                      if (active) ...[
                        const SizedBox(width: 5),
                        Icon(Icons.check_circle, size: 14, color: group.color),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Marker widgets ────────────────────────────────────────────────────────────
class _MarkerPin extends StatelessWidget {
  final Color    color;
  final IconData icon;
  final bool     selected;
  final String?  badge;
  const _MarkerPin(
      {required this.color, required this.icon, required this.selected, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.88),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: selected ? 3 : 2),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.45), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: Colors.white, size: selected ? 21 : 18),
      ),
      if (badge != null)
        Positioned(
          top: -5, right: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Text(badge!,
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold, color: color)),
          ),
        ),
    ]);
  }
}

class _PillBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PillBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: Colors.white, shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Icon(icon, size: 20, color: AppTheme.textDark),
    ),
  );
}

// ── Place strip ───────────────────────────────────────────────────────────────
class _PlaceStrip extends StatelessWidget {
  final List<PlaceModel> places;
  final String?          selectedId;
  final Position?        userPos;
  final void Function(PlaceModel) onTap;
  const _PlaceStrip({
    required this.places, this.selectedId,
    this.userPos, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 108,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      itemCount: places.length,
      itemBuilder: (_, i) {
        final p   = places[i];
        final sel = p.id == selectedId;
        final col = catColor(p.category);

        // Distance label
        String? distLabel;
        if (userPos != null && p.lat != null && p.lng != null) {
          final d = _distanceMeters(
              userPos!.latitude, userPos!.longitude, p.lat!, p.lng!);
          distLabel = _formatDistance(d);
        }

        return GestureDetector(
          onTap: () => onTap(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 160, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: sel ? Border.all(color: col, width: 2) : null,
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: p.imageUrl, width: 56,
                  height: double.infinity, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                      width: 56, color: col.withOpacity(0.15),
                      child: Icon(catIcon(p.category),
                          color: col.withOpacity(0.5), size: 20)),
                ),
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: AppTheme.textDark),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      if (!p.category.startsWith('transport')) ...[
                        const Icon(Icons.star, size: 10, color: AppTheme.amber),
                        Flexible(child: Text(' ${p.rating}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textGrey),
                            overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                      ],
                      if (distLabel != null) ...[
                        const Icon(Icons.near_me, size: 10, color: AppTheme.primaryGreen),
                        const SizedBox(width: 2),
                        Flexible(child: Text(distLabel,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                  ],
                ),
              )),
            ]),
          ),
        );
      },
    ),
  );
}

// ── Bottom Sheet ──────────────────────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final PlaceModel   place;
  final Position?    userPos;
  final VoidCallback onClose;
  final VoidCallback onDetail;
  const _BottomSheet({
    required this.place, this.userPos,
    required this.onClose, required this.onDetail,
  });

  bool _isTransport(String cat) =>
      cat == 'transport' || cat.startsWith('transport_');

  // Distance label for the sheet header
  String? get _distLabel {
    if (userPos == null || place.lat == null || place.lng == null) return null;
    final d = _distanceMeters(
        userPos!.latitude, userPos!.longitude, place.lat!, place.lng!);
    return _formatDistance(d);
  }

  @override
  Widget build(BuildContext context) {
    final col = catColor(place.category);

    // ── YouBike ───────────────────────────────────────────────────────────
    if (place.category == 'transport_bike') {
      final avail  = place.tags.length > 1 ? (int.tryParse(place.tags[1]) ?? 0) : 0;
      final spaces = place.tags.length > 2 ? (int.tryParse(place.tags[2]) ?? 0) : 0;
      final total  = place.tags.length > 3
          ? (int.tryParse(place.tags[3]) ?? 0) : (avail + spaces);
      final ratio  = total > 0 ? avail / total : 0.0;
      final barCol = avail == 0 ? Colors.red.shade400
          : ratio > 0.5 ? col : Colors.orange;

      return _SheetWrapper(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _CategoryIcon(color: col, icon: Icons.pedal_bike_rounded),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(place.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (place.location.isNotEmpty)
                      Expanded(child: Text(place.location,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (_distLabel != null) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.near_me, size: 11, color: AppTheme.primaryGreen),
                      Text(' $_distLabel',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500)),
                    ],
                  ]),
                ])),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textGrey)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _BikeStatTile(
                    icon: Icons.directions_bike_rounded,
                    label: '可借車輛', count: avail, unit: '輛', color: col)),
                const SizedBox(width: 12),
                Expanded(child: _BikeStatTile(
                    icon: Icons.local_parking_rounded,
                    label: '可還空位', count: spaces, unit: '格',
                    color: const Color(0xFF2563EB))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Text('使用率 ${total > 0 ? (ratio * 100).round() : 0}%',
                    style: TextStyle(
                        fontSize: 11, color: barCol, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('共 $total 格',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: ratio, minHeight: 8,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(barCol),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _openNavigation(place, userPos),
                  icon: const Icon(Icons.navigation_rounded, size: 13),
                  label: const Text('導航前往', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => showTransportSheet(context, place),
                  icon: const Icon(Icons.refresh, size: 13),
                  label: const Text('即時更新', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: col, side: BorderSide(color: col),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero),
                )),
              ]),
            ]),
          ),
        ]),
      );
    }

    // ── Train station ─────────────────────────────────────────────────────
    if (place.category == 'transport_train') {
      return _SheetWrapper(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const _CategoryIcon(color: const Color(0xFFDC2626), icon: Icons.train),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('嘉義火車站',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Row(children: [
                    const Expanded(child: Text('嘉義市東區中山路528號',
                        style: TextStyle(fontSize: 11, color: AppTheme.textGrey))),
                    if (_distLabel != null) ...[
                      const Icon(Icons.near_me, size: 11, color: AppTheme.primaryGreen),
                      Text(' $_distLabel',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500)),
                    ],
                  ]),
                ])),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textGrey)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                    onPressed: () => _openNavigation(place, userPos),
                    icon: const Icon(Icons.navigation_rounded, size: 13),
                    label: const Text('導航前往', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        minimumSize: Size.zero))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                    onPressed: () => showTransportSheet(context, place),
                    icon: const Icon(Icons.schedule, size: 14),
                    label: const Text('火車時刻', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        minimumSize: Size.zero))),
              ]),
            ]),
          ),
        ]),
      );
    }

    // ── Bus stop ──────────────────────────────────────────────────────────
    if (place.category == 'transport_bus' || place.category == 'transport') {
      return _SheetWrapper(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _CategoryIcon(color: col, icon: Icons.directions_bus_rounded),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(place.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    if (place.location.isNotEmpty)
                      Expanded(child: Text(place.location,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (_distLabel != null) ...[
                      const Icon(Icons.near_me, size: 11, color: AppTheme.primaryGreen),
                      Text(' $_distLabel',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w500)),
                    ],
                  ]),
                ])),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textGrey)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                    onPressed: () => _openNavigation(place, userPos),
                    icon: const Icon(Icons.navigation_rounded, size: 13),
                    label: const Text('導航前往', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        minimumSize: Size.zero))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                    onPressed: () => showTransportSheet(context, place),
                    icon: const Icon(Icons.sensors, size: 14),
                    label: const Text('即時動態', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: col,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        minimumSize: Size.zero))),
              ]),
            ]),
          ),
        ]),
      );
    }

    // ── General place ─────────────────────────────────────────────────────
    return _SheetWrapper(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: place.imageUrl, width: 88, height: 88, fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 88, height: 88, color: col.withOpacity(0.15)),
                errorWidget: (_, __, ___) => Container(
                    width: 88, height: 88, color: col.withOpacity(0.1),
                    child: Icon(catIcon(place.category),
                        color: col.withOpacity(0.5), size: 32)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(place.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: AppTheme.textDark),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                GestureDetector(onTap: onClose,
                    child: const Icon(Icons.close, size: 18, color: AppTheme.textGrey)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, size: 12, color: AppTheme.primaryGreen),
                const SizedBox(width: 3),
                Expanded(child: Text(place.location,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              if (_distLabel != null) ...[
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.near_me, size: 12, color: AppTheme.primaryGreen),
                  const SizedBox(width: 3),
                  Text('距離 $_distLabel',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w500)),
                ]),
              ],
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.star, size: 12, color: AppTheme.amber),
                Text(' ${place.rating}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: col.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(_catLabel[place.category] ?? place.category,
                      style: TextStyle(
                          fontSize: 10, color: col, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Consumer<FavoritesService>(builder: (_, fav, __) => GestureDetector(
                  onTap: () => fav.toggle(place.id),
                  child: Icon(
                    fav.isFavorite(place.id) ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: fav.isFavorite(place.id) ? Colors.red : Colors.grey,
                  ),
                )),
              ]),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                    onPressed: () => _openNavigation(place, userPos),
                    icon: const Icon(Icons.navigation_rounded, size: 13),
                    label: const Text('導航前往', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        minimumSize: Size.zero))),
                const SizedBox(width: 8),
                if (_isTransport(place.category))
                  Expanded(child: ElevatedButton.icon(
                      onPressed: () => showTransportSheet(context, place),
                      icon: const Icon(Icons.sensors, size: 14),
                      label: const Text('即時動態', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: col,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          minimumSize: Size.zero)))
                else
                  Expanded(child: ElevatedButton(
                      onPressed: onDetail,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          minimumSize: Size.zero),
                      child: const Text('詳細資訊', style: TextStyle(fontSize: 12)))),
              ]),
            ])),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared sheet helpers ──────────────────────────────────────────────────────
class _SheetWrapper extends StatelessWidget {
  final Widget child;
  const _SheetWrapper({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.14), blurRadius: 20,
          offset: const Offset(0, -4))],
    ),
    child: child,
  );
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Container(
    margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
    decoration: BoxDecoration(
        color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
  ));
}

class _CategoryIcon extends StatelessWidget {
  final Color    color;
  final IconData icon;
  const _CategoryIcon({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
    child: Icon(icon, color: color, size: 20),
  );
}

class _BikeStatTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count;
  final String   unit;
  final Color    color;
  const _BikeStatTile(
      {required this.icon, required this.label,
        required this.count, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.85))),
      ]),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: color, height: 1.0)),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(unit,
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.8))),
        ),
      ]),
    ]),
  );
}