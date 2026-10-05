// lib/pages/transport_page.dart
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/transport_model.dart';
import '../services/transport_service.dart';

class TransportPage extends StatefulWidget {
  const TransportPage({super.key});
  @override
  State<TransportPage> createState() => _TransportPageState();
}

class _TransportPageState extends State<TransportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _svc = TransportService();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('即時交通'),
        backgroundColor: AppTheme.primaryGreen,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.pedal_bike),      text: '腳踏車'),
            Tab(icon: Icon(Icons.directions_bus),  text: '公車'),
            Tab(icon: Icon(Icons.train),           text: '火車'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _YouBikeTab(svc: _svc),
        _BusTab(svc: _svc),
        _TrainTab(svc: _svc),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 公車 Tab
// ─────────────────────────────────────────────────────────────────────────────
class _BusTab extends StatefulWidget {
  final TransportService svc;
  const _BusTab({required this.svc});
  @override
  State<_BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<_BusTab> {
  final _routeCtrl = TextEditingController();
  List<BusRoute>? _results;
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    // 預載所有路線（顯示全部）
    _search('');
  }

  @override
  void dispose() {
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _lastQuery = query; });
    try {
      final results = await widget.svc.getBusRoutes(query: query);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.svc.isUsingMock) const _MockBanner(),

      // 路線搜尋
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _routeCtrl,
              decoration: InputDecoration(
                hintText: '搜尋路線號碼（如：7322、A01）',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
                suffixIcon: _routeCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.textGrey),
                  onPressed: () {
                    _routeCtrl.clear();
                    _search('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) {
                setState(() {}); // 更新 suffixIcon 顯示
                _search(v.trim());
              },
              onSubmitted: (v) => _search(v.trim()),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _search(_routeCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('查詢'),
          ),
        ]),
      ),

      const _InfoBanner(
        icon: Icons.directions_bus,
        text: '嘉義公車路線查詢',
      ),

      Expanded(
        child: _loading
            ? const _LoadingView(message: '搜尋路線中...')
            : (_results == null || _results!.isEmpty)
            ? _EmptyView(
          icon: Icons.directions_bus_outlined,
          message: _lastQuery.isEmpty ? '暫無路線資料' : '找不到「$_lastQuery」',
          sub: _lastQuery.isEmpty ? '請稍後再試' : '請嘗試其他關鍵字',
          onRetry: () => _search(_routeCtrl.text.trim()),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: _results!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _BusRouteCard(route: _results![i]),
        ),
      ),
    ]);
  }
}

class _BusRouteCard extends StatelessWidget {
  final BusRoute route;
  const _BusRouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        // 路線號碼 badge
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_bus, color: AppTheme.primaryGreen, size: 18),
              const SizedBox(height: 2),
              Text(route.routeName,
                  style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
        const SizedBox(width: 12),

        // 起終點 + 業者
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(route.departureStop,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 14, color: AppTheme.textGrey),
            ),
            Flexible(
              child: Text(route.destinationStop,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (route.operatorName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textGrey.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(route.operatorName,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
              ),
              if (route.hasWheelchair) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('♿',
                      style: TextStyle(fontSize: 11, color: AppTheme.primaryGreen)),
                ),
              ],
            ]),
          ],
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 台鐵 Tab
// ─────────────────────────────────────────────────────────────────────────────
class _TrainTab extends StatefulWidget {
  final TransportService svc;
  const _TrainTab({required this.svc});
  @override
  State<_TrainTab> createState() => _TrainTabState();
}

class _TrainTabState extends State<_TrainTab>
    with SingleTickerProviderStateMixin {
  late Future<List<TrainSchedule>> _future;
  late TabController _dirTab;

  static const _northKeywords = [
    '台北', '台中', '新竹', '基隆', '斗六', '彰化', '豐原', '苗栗',
    '桃園', '板橋', '松山', '七堵', '樹林', '嘉義以北'
  ];
  static const _southKeywords = [
    '台南', '高雄', '屏東', '左營', '新左營', '潮州', '枋寮',
    '善化', '新市', '永康', '鳳山',
  ];

  @override
  void initState() {
    super.initState();
    _dirTab = TabController(length: 2, vsync: this);
    _future = widget.svc.getTrainSchedules();
  }

  @override
  void dispose() {
    _dirTab.dispose();
    super.dispose();
  }

  void _refresh() =>
      setState(() => _future = widget.svc.getTrainSchedules());

  List<TrainSchedule> _filter(List<TrainSchedule> all, bool north) {
    final keywords = north ? _northKeywords : _southKeywords;
    final filtered = all.where((t) =>
        keywords.any((k) => t.arrivalStation.contains(k))).toList();
    // If nothing matched, put everything in north tab
    return filtered.isEmpty && north ? all : filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.svc.isUsingMock) const _MockBanner(),

      // Direction Tab
      Container(
        color: Colors.grey.shade50,
        child: TabBar(
          controller: _dirTab,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.north, size: 15),
                SizedBox(width: 5),
                Text('北上'),
              ]),
            ),
            Tab(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.south, size: 15),
                SizedBox(width: 5),
                Text('南下'),
              ]),
            ),
          ],
        ),
      ),

      const _InfoBanner(
        icon: Icons.train,
        text: '嘉義火車站今日時刻表（下拉更新）',
      ),

      Expanded(
        child: FutureBuilder<List<TrainSchedule>>(
          future: _future,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingView(message: '載入台鐵資料中...');
            }
            if (snap.hasError) return _ErrorView(onRetry: _refresh);
            final all = snap.data ?? [];

            if (all.isEmpty) {
              return _EmptyView(
                icon: Icons.train_outlined,
                message: '今日無更多班次',
                sub: '已是當日最後班次，或資料更新中',
                onRetry: _refresh,
              );
            }

            return TabBarView(
              controller: _dirTab,
              children: [
                _TrainDirectionList(
                  trains: _filter(all, true),
                  direction: '北上',
                  onRefresh: _refresh,
                ),
                _TrainDirectionList(
                  trains: _filter(all, false),
                  direction: '南下',
                  onRefresh: _refresh,
                ),
              ],
            );
          },
        ),
      ),
    ]);
  }
}

class _TrainDirectionList extends StatelessWidget {
  final List<TrainSchedule> trains;
  final String direction;
  final VoidCallback onRefresh;
  const _TrainDirectionList({
    required this.trains,
    required this.direction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (trains.isEmpty) {
      return _EmptyView(
        icon: Icons.train_outlined,
        message: '暫無$direction班次',
        sub: '今日已無更多$direction班次',
        onRetry: onRefresh,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: const Color(0xFFDC2626),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: trains.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TrainCard(train: trains[i]),
      ),
    );
  }
}

class _TrainCard extends StatelessWidget {
  final TrainSchedule train;
  const _TrainCard({required this.train});

  Color _typeColor(String type) {
    if (type.contains('自強'))             return const Color(0xFFDC2626);
    if (type.contains('普悠瑪') || type.contains('太魯閣')) return const Color(0xFF00739D);
    if (type.contains('莒光'))             return const Color(0xFFD97706);
    if (type.contains('區間快'))           return const Color(0xFF16A34A);
    if (type.contains('區間'))             return const Color(0xFF6B7280);
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    final delayed = int.tryParse(train.delayTime) ?? 0;
    final col = _typeColor(train.trainType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: delayed > 0 ? Border.all(color: Colors.orange.shade200) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        // 車次 + 類型
        SizedBox(width: 64, child: Column(children: [
          Text(train.trainNo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
            child: Text(train.trainType,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ])),

        const SizedBox(width: 14),

        // 路線 + 時間
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(train.departureStation,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 14, color: col),
            ),
            Text(train.arrivalStation,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.access_time, size: 13, color: AppTheme.textGrey),
            const SizedBox(width: 3),
            Text('${train.departureTime} → ${train.arrivalTime}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          ]),
        ])),

        // 誤點 / 準點
        if (delayed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Text('誤點',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 10)),
              Text('$delayed 分',
                  style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Column(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(height: 2),
              Text('準點', style: TextStyle(color: Colors.green, fontSize: 10)),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouBike Tab
// ─────────────────────────────────────────────────────────────────────────────
class _YouBikeTab extends StatefulWidget {
  final TransportService svc;
  const _YouBikeTab({required this.svc});
  @override
  State<_YouBikeTab> createState() => _YouBikeTabState();
}

class _YouBikeTabState extends State<_YouBikeTab> {
  late Future<List<YouBikeStation>> _future;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.svc.getYouBikeStations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    widget.svc.clearCache();
    setState(() => _future = widget.svc.getYouBikeStations());
  }

  List<YouBikeStation> _filtered(List<YouBikeStation> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((s) =>
    s.stationName.toLowerCase().contains(q) ||
        s.address.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.svc.isUsingMock) const _MockBanner(),

      // 搜尋欄
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '搜尋站點名稱或地址',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.textGrey),
                  onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
            tooltip: '重新整理',
            onPressed: _refresh,
          ),
        ]),
      ),

      const _InfoBanner(icon: Icons.pedal_bike, text: '嘉義市 YouBike 即時站點（下拉更新）'),

      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: AppTheme.primaryGreen,
          child: FutureBuilder<List<YouBikeStation>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingView(message: '載入 YouBike 資料中...');
              }
              if (snap.hasError) return _ErrorView(onRetry: _refresh);
              final stations = _filtered(snap.data ?? []);
              if (stations.isEmpty) {
                return _EmptyView(
                  icon: Icons.pedal_bike_outlined,
                  message: _query.isNotEmpty ? '找不到「$_query」' : '查無站點資料',
                  sub: _query.isNotEmpty ? '請嘗試其他關鍵字' : '嘉義市可能尚未建置 YouBike 或資料更新中',
                  onRetry: _refresh,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: stations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _YouBikeCard(station: stations[i]),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

class _YouBikeCard extends StatelessWidget {
  final YouBikeStation station;
  const _YouBikeCard({required this.station});

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pedal_bike, color: Color(0xFF16A34A), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(station.stationName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if (station.address.isNotEmpty)
                    Text(station.address,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textGrey),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                child: _YouBikeDetailContent(station: station),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = station.totalSpaces > 0
        ? station.availableBikes / station.totalSpaces
        : 0.0;
    final barColor = ratio > 0.5
        ? AppTheme.primaryGreen
        : ratio > 0.2
        ? Colors.orange
        : Colors.red.shade400;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 站名
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.pedal_bike, color: AppTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(station.stationName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (station.address.isNotEmpty)
                Text(station.address,
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),

          const SizedBox(height: 10),

          // 進度條
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),

          const SizedBox(height: 8),

          // 數量
          Row(children: [
            _BikeCount(icon: Icons.directions_bike, label: '可借', count: station.availableBikes, color: AppTheme.primaryGreen),
            const SizedBox(width: 16),
            _BikeCount(icon: Icons.local_parking, label: '空位', count: station.availableSpaces, color: const Color(0xFF2563EB)),
            const Spacer(),
            Text('共 ${station.totalSpaces} 格',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _BikeCount extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _BikeCount({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 4),
      Text('$label ', style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
      Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

/// YouBike 站點詳細資訊（底部彈窗內容）
class _YouBikeDetailContent extends StatelessWidget {
  final YouBikeStation station;
  const _YouBikeDetailContent({required this.station});

  @override
  Widget build(BuildContext context) {
    final ratio = station.totalSpaces > 0
        ? station.availableBikes / station.totalSpaces
        : 0.0;
    final barColor = ratio > 0.5
        ? AppTheme.primaryGreen
        : ratio > 0.2
        ? Colors.orange
        : Colors.red.shade400;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _StatBox(
          icon: Icons.directions_bike,
          label: '可借車輛',
          value: '${station.availableBikes}',
          unit: '輛',
          color: AppTheme.primaryGreen,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatBox(
          icon: Icons.local_parking,
          label: '可還空位',
          value: '${station.availableSpaces}',
          unit: '格',
          color: const Color(0xFF2563EB),
        )),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        const Text('使用率', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
        const Spacer(),
        Text('共 ${station.totalSpaces} 格',
            style: const TextStyle(fontSize: 12, color: AppTheme.textGrey)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 9,
          backgroundColor: Colors.grey.shade100,
          valueColor: AlwaysStoppedAnimation(barColor),
        ),
      ),
      if (station.address.isNotEmpty) ...[
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.location_on, size: 14, color: AppTheme.textGrey),
          const SizedBox(width: 4),
          Expanded(child: Text(station.address,
              style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))),
        ]),
      ],
    ]);
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 3),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(unit, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 共用元件
// ─────────────────────────────────────────────────────────────────────────────

/// 未設定金鑰時顯示的提示 Banner
class _MockBanner extends StatelessWidget {
  const _MockBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '目前顯示示範資料。請在 transport_service.dart 填入 TDX 金鑰以取得即時資料。',
            style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
          ),
        ),
      ]),
    );
  }
}

/// 狀態 Banner（綠色）
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primaryGreen.withOpacity(0.07),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen)),
      ]),
    );
  }
}

/// 載入中
class _LoadingView extends StatelessWidget {
  final String message;
  const _LoadingView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: AppTheme.primaryGreen),
      const SizedBox(height: 16),
      Text(message, style: const TextStyle(color: AppTheme.textGrey)),
    ]));
  }
}

/// 錯誤（不再顯示紅字，改為友善提示）
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('無法取得資料', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('請確認網路連線，或 TDX 金鑰是否正確',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('重新嘗試'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
        ),
      ]),
    ));
  }
}

/// 空資料
class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;
  final VoidCallback onRetry;
  const _EmptyView({required this.icon, required this.message, required this.sub, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 8),
        Text(sub, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryGreen),
          label: const Text('重新整理', style: TextStyle(color: AppTheme.primaryGreen)),
        ),
      ]),
    ));
  }
}