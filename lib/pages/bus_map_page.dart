// lib/pages/bus_map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../models/transport_model.dart';
import '../services/transport_service.dart';

// ── 顏色常數 ──────────────────────────────────────────────────────────────────
const _busColor   = Color(0xFF1D4ED8); // 深藍
const _bikeColor  = Color(0xFF16A34A); // 深綠

class BusMapPage extends StatefulWidget {
  const BusMapPage({super.key});

  @override
  State<BusMapPage> createState() => _BusMapPageState();
}

class _BusMapPageState extends State<BusMapPage> {
  final _svc = TransportService();

  List<BusStop>       _busStops  = [];
  List<YouBikeStation> _bikeStops = [];

  bool _busLoading  = true;
  bool _bikeLoading = true;

  bool _showBus  = true;
  bool _showBike = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // 同時載入，不互相等待
    await Future.wait([_loadBus(), _loadBike()]);
  }

  Future<void> _loadBus() async {
    final stops = await _svc.getBusStops();
    if (mounted) setState(() { _busStops = stops; _busLoading = false; });
  }

  Future<void> _loadBike() async {
    final stations = await _svc.getYouBikeStations();
    if (mounted) setState(() { _bikeStops = stations; _bikeLoading = false; });
  }

  bool get _loading => _busLoading || _bikeLoading;

  // ── 點擊公車站 ─────────────────────────────────────────────────────────────
  void _showBusDetail(BusStop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BusStopSheet(stop: stop, service: _svc),
    );
  }

  // ── 點擊 YouBike 站 ────────────────────────────────────────────────────────
  void _showBikeDetail(YouBikeStation station) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _YouBikeStationSheet(initialStation: station, svc: _svc),
    );
  }

  // ── 建立公車 Marker 列表 ───────────────────────────────────────────────────
  List<Marker> get _busMarkers => _busStops.map((stop) => Marker(
    point: LatLng(stop.lat, stop.lng),
    width: 36, height: 36,
    child: GestureDetector(
      onTap: () => _showBusDetail(stop),
      child: const _PinWidget(
        icon: Icons.directions_bus_rounded,
        color: _busColor,
        size: 18,
      ),
    ),
  )).toList();

  // ── 建立 YouBike Marker 列表 ───────────────────────────────────────────────
  List<Marker> get _bikeMarkers => _bikeStops.map((station) {
    // 顏色依可借數量變化：0=紅 少=橘 多=綠
    final Color pinColor = station.availableBikes == 0
        ? Colors.red.shade600
        : station.availableBikes <= 2
        ? Colors.orange.shade600
        : _bikeColor;

    return Marker(
      point: LatLng(station.lat, station.lng),
      width: 40, height: 40,
      child: GestureDetector(
        onTap: () => _showBikeDetail(station),
        child: _PinWidget(
          icon: Icons.pedal_bike_rounded,
          color: pinColor,
          size: 20,
          badge: station.availableBikes > 0
              ? '${station.availableBikes}'
              : null,
        ),
      ),
    );
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('嘉義交通站點地圖'),
        backgroundColor: const Color(0xFF0D9488),
        actions: [
          // 載入指示
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_showBus)
                  Text('${_busStops.length}站',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                if (_showBus && _showBike)
                  const Text(' / ',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                if (_showBike)
                  Text('${_bikeStops.length}站',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
              ]),
            ),
        ],
      ),

      body: Stack(children: [
        // ── 地圖 ──────────────────────────────────────────────────────────────
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(23.4800, 120.4490),
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),

            // 公車站層（藍色）
            if (_showBus && _busStops.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(38, 38),
                  markers: _busMarkers,
                  builder: (context, markers) => _ClusterWidget(
                    count: markers.length,
                    color: _busColor,
                  ),
                ),
              ),

            // YouBike 層（綠色）
            if (_showBike && _bikeStops.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(38, 38),
                  markers: _bikeMarkers,
                  builder: (context, markers) => _ClusterWidget(
                    count: markers.length,
                    color: _bikeColor,
                  ),
                ),
              ),
          ],
        ),

        // ── 圖例 / 切換按鈕（左下角）──────────────────────────────────────────
        Positioned(
          left: 12, bottom: 24,
          child: _LayerToggle(
            showBus:   _showBus,
            showBike:  _showBike,
            busCount:  _busStops.length,
            bikeCount: _bikeStops.length,
            onToggleBus:  () => setState(() => _showBus  = !_showBus),
            onToggleBike: () => setState(() => _showBike = !_showBike),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pin 圖示元件
// ─────────────────────────────────────────────────────────────────────────────
class _PinWidget extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final double   size;
  final String?  badge; // 小角標（可借數量）

  const _PinWidget({
    required this.icon,
    required this.color,
    required this.size,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
        // 角標：顯示可借數量
        if (badge != null)
          Positioned(
            top: -4, right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 群聚 Marker
// ─────────────────────────────────────────────────────────────────────────────
class _ClusterWidget extends StatelessWidget {
  final int   count;
  final Color color;
  const _ClusterWidget({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
    ),
    child: Center(
      child: Text('$count',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 圖例 + 開關按鈕
// ─────────────────────────────────────────────────────────────────────────────
class _LayerToggle extends StatelessWidget {
  final bool showBus;
  final bool showBike;
  final int  busCount;
  final int  bikeCount;
  final VoidCallback onToggleBus;
  final VoidCallback onToggleBike;

  const _LayerToggle({
    required this.showBus,
    required this.showBike,
    required this.busCount,
    required this.bikeCount,
    required this.onToggleBus,
    required this.onToggleBike,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToggleRow(
            icon: Icons.directions_bus_rounded,
            color: _busColor,
            label: '公車站',
            count: busCount,
            active: showBus,
            onTap: onToggleBus,
          ),
          const SizedBox(height: 6),
          _ToggleRow(
            icon: Icons.pedal_bike_rounded,
            color: _bikeColor,
            label: 'YouBike',
            count: bikeCount,
            active: showBike,
            onTap: onToggleBike,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final int      count;
  final bool     active;
  final VoidCallback onTap;

  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: active ? Colors.white : Colors.grey.shade400,
              size: 15),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.black87 : Colors.grey.shade400)),
        const SizedBox(width: 4),
        Text('$count',
            style: TextStyle(
                fontSize: 11,
                color: active ? color : Colors.grey.shade400)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 公車站底部彈窗（原有邏輯，樣式統一）
// ─────────────────────────────────────────────────────────────────────────────
class _BusStopSheet extends StatefulWidget {
  final BusStop stop;
  final TransportService service;
  const _BusStopSheet({required this.stop, required this.service});

  @override
  State<_BusStopSheet> createState() => _BusStopSheetState();
}

class _BusStopSheetState extends State<_BusStopSheet> {
  List<BusArrival> _arrivals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await widget.service.getBusArrivalsByStop(widget.stop.stopUID);
    if (mounted) setState(() { _arrivals = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          // 把手
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 38, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          // 標題
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _busColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: _busColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.stop.stopName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (widget.stop.address.isNotEmpty)
                      Text(widget.stop.address,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
              _loading
                  ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _busColor)))
                  : IconButton(
                  icon: const Icon(Icons.refresh, color: _busColor),
                  onPressed: _load),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          const Divider(height: 1),

          // 路線列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _busColor))
                : _arrivals.isEmpty
                ? const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined, size: 48,
                      color: Color(0xFFDDD)),
                  SizedBox(height: 12),
                  Text('目前無公車動態',
                      style: TextStyle(color: Colors.grey)),
                ]))
                : ListView.separated(
              controller: controller,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: _arrivals.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final a = _arrivals[i];
                final arriving = a.estimateTime == '即將進站';
                final Color tc = arriving
                    ? Colors.green.shade700
                    : _busColor;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: arriving
                        ? Colors.green.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: arriving
                            ? Colors.green.shade200
                            : Colors.grey.shade100),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(a.routeName,
                          style: TextStyle(
                              color: tc,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(a.direction,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tc.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(a.estimateTime,
                          style: TextStyle(
                              color: tc,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouBike 站底部彈窗（可借 / 可還大數字）
// ─────────────────────────────────────────────────────────────────────────────
class _YouBikeStationSheet extends StatefulWidget {
  final YouBikeStation   initialStation;
  final TransportService svc;
  const _YouBikeStationSheet(
      {required this.initialStation, required this.svc});

  @override
  // ignore: library_private_types_in_public_api
  State<_YouBikeStationSheet> createState() =>
      _YouBikeStationSheetState();
}

class _YouBikeStationSheetState extends State<_YouBikeStationSheet> {
  late YouBikeStation _station;
  bool      _loading = false;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _station    = widget.initialStation;
    _lastUpdate = DateTime.now();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      widget.svc.clearCache();
      final all = await widget.svc.getYouBikeStations();
      final updated = all.firstWhere(
            (s) => s.stationId == _station.stationId,
        orElse: () => _station,
      );
      setState(() {
        _station    = updated;
        _lastUpdate = DateTime.now();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _station.totalSpaces > 0
        ? _station.availableBikes / _station.totalSpaces
        : 0.0;
    final Color barColor = _station.availableBikes == 0
        ? Colors.red.shade400
        : ratio > 0.5
        ? _bikeColor
        : Colors.orange;

    return DraggableScrollableSheet(
      initialChildSize: 0.50,
      minChildSize: 0.35,
      maxChildSize: 0.75,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          // 把手
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 38, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),

          // 標題列
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _bikeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pedal_bike_rounded,
                    color: _bikeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_station.stationName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_station.address.isNotEmpty)
                      Text(_station.address,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
              _loading
                  ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _bikeColor)))
                  : IconButton(
                  icon: const Icon(Icons.refresh, color: _bikeColor),
                  tooltip: '更新即時資料',
                  onPressed: _refresh),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          const Divider(height: 1),

          // 內容
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 大數字區 ───────────────────────────────────────
                    Row(children: [
                      Expanded(child: _BigTile(
                        icon: Icons.directions_bike_rounded,
                        label: '可借車輛',
                        count: _station.availableBikes,
                        unit: '輛',
                        color: _bikeColor,
                      )),
                      const SizedBox(width: 14),
                      Expanded(child: _BigTile(
                        icon: Icons.local_parking_rounded,
                        label: '可還空位',
                        count: _station.availableSpaces,
                        unit: '格',
                        color: const Color(0xFF2563EB),
                      )),
                    ]),

                    const SizedBox(height: 20),

                    // ── 使用率 ─────────────────────────────────────────
                    Row(children: [
                      Text('使用率 ${(ratio * 100).round()}%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: barColor)),
                      const Spacer(),
                      Text('總容量 ${_station.totalSpaces} 格',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation(barColor),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── 狀態標籤 ───────────────────────────────────────
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (_station.availableBikes == 0)
                        _Chip(label: '🚲 無車可借', color: Colors.red.shade400),
                      if (_station.availableSpaces == 0)
                        const _Chip(label: '🅿 無位可還', color: Colors.orange),
                      if (_station.availableBikes > 0 &&
                          _station.availableSpaces > 0)
                        const _Chip(label: '✓ 正常服務', color: _bikeColor),
                      if (_station.availableBikes > 5)
                        _Chip(
                            label: '充足 ${_station.availableBikes} 輛',
                            color: Colors.green.shade600),
                    ]),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── 更新時間 ───────────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '最後更新 ${_lastUpdate != null ? '${_lastUpdate!.hour.toString().padLeft(2, '0')}:${_lastUpdate!.minute.toString().padLeft(2, '0')}' : '--:--'}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _loading ? null : _refresh,
                            child: Text('點此更新',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _loading
                                        ? Colors.grey.shade300
                                        : _bikeColor,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline)),
                          ),
                        ]),
                    const SizedBox(height: 8),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 大數字磚塊 ─────────────────────────────────────────────────────────────────
class _BigTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final int      count;
  final String   unit;
  final Color    color;
  const _BigTile({
    required this.icon, required this.label,
    required this.count, required this.unit, required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color.withOpacity(0.85))),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$count',
            style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0)),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(unit,
              style: TextStyle(
                  fontSize: 14, color: color.withOpacity(0.8))),
        ),
      ]),
    ]),
  );
}

// ── 狀態標籤 ──────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label,
        style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600)),
  );
}