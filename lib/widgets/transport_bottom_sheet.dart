// lib/widgets/transport_bottom_sheet.dart
//
// 地圖上點擊交通站點後顯示的即時資訊底部彈窗
// 支援三種類型：腳踏車（YouBike）、公車站牌、火車站
//
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../models/transport_model.dart';
import '../services/transport_service.dart';

// ── 判斷站點類型 ─────────────────────────────────────────────────────────────
enum _StationType { bike, bus, train, unknown }

_StationType _detectType(PlaceModel place) {
  final cat  = place.category.toLowerCase();
  final tags = place.tags.map((t) => t.toLowerCase()).toList();
  final name = place.name.toLowerCase();

  if (cat.contains('bike') || tags.contains('bike') || tags.contains('youbike') ||
      name.contains('youbike') || name.contains('單車') || name.contains('腳踏車') ||
      cat == 'transport_bike') {
    return _StationType.bike;
  }
  if (cat.contains('train') || tags.contains('train') || tags.contains('台鐵') ||
      name.contains('火車') || name.contains('台鐵') || name.contains('高鐵') ||
      cat == 'transport_train') {
    return _StationType.train;
  }
  if (cat.contains('bus') || tags.contains('bus') || tags.contains('公車') ||
      name.contains('公車') || name.contains('bus') ||
      cat == 'transport_bus' || cat == 'transport') {
    return _StationType.bus;
  }
  return _StationType.unknown;
}

// ── 主入口：show the sheet ───────────────────────────────────────────────────
void showTransportSheet(BuildContext context, PlaceModel place) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransportSheet(place: place),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _TransportSheet
// ─────────────────────────────────────────────────────────────────────────────
class _TransportSheet extends StatelessWidget {
  final PlaceModel place;
  const _TransportSheet({required this.place});

  @override
  Widget build(BuildContext context) {
    final type = _detectType(place);

    Widget body;
    switch (type) {
      case _StationType.bike:
        body = _YouBikePanel(place: place);
        break;
      case _StationType.bus:
        body = _BusPanel(place: place);
        break;
      case _StationType.train:
        body = _TrainPanel(place: place);
        break;
      case _StationType.unknown:
      // 若分不清楚，顯示公車（最常見的交通站）
        body = _BusPanel(place: place);
        break;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.25,
      maxChildSize: 0.88,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 38, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          _SheetHeader(place: place, type: type),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              child: body,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Sheet 標題列 ──────────────────────────────────────────────────────────────
class _SheetHeader extends StatelessWidget {
  final PlaceModel place;
  final _StationType type;
  const _SheetHeader({required this.place, required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (type) {
      _StationType.bike    => (Icons.pedal_bike,      const Color(0xFF16A34A), 'YouBike 站點'),
      _StationType.bus     => (Icons.directions_bus,  const Color(0xFF0D9488), '公車站牌'),
      _StationType.train   => (Icons.train,           const Color(0xFFDC2626), '火車站'),
      _StationType.unknown => (Icons.directions_bus,  AppTheme.primaryGreen,   '交通站點'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(place.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: AppTheme.textDark),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label,
                  style: TextStyle(fontSize: 10, color: color,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(place.location,
                style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textGrey, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouBike Panel
// ─────────────────────────────────────────────────────────────────────────────
class _YouBikePanel extends StatefulWidget {
  final PlaceModel place;
  const _YouBikePanel({required this.place});
  @override
  State<_YouBikePanel> createState() => _YouBikePanelState();
}

class _YouBikePanelState extends State<_YouBikePanel> {
  final _svc = TransportService();
  late Future<List<YouBikeStation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _svc.getYouBikeStations();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<YouBikeStation>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCell(message: '載入 YouBike 資料中...');
        }
        if (snap.hasError) {
          return _RetryCell(
              message: '無法取得資料', onRetry: () => setState(() => _future = _svc.getYouBikeStations()));
        }

        // 嘗試比對站名
        final stations = snap.data ?? [];
        YouBikeStation? matched;
        final nameParts = widget.place.name.replaceAll('YouBike', '').replaceAll('youbike', '').trim();
        if (nameParts.isNotEmpty) {
          try {
            matched = stations.firstWhere((s) =>
            s.stationName.contains(nameParts) || nameParts.contains(s.stationName));
          } catch (_) {
            matched = null;
          }
        }

        if (matched != null) {
          return _YouBikeDetail(station: matched);
        }

        // 若找不到精確站，列出所有站點
        return Column(children: [
          const _InfoBanner(
            icon: Icons.info_outline,
            text: '以下為嘉義市所有 YouBike 站點即時資訊',
            color: Color(0xFF16A34A),
          ),
          ...stations.map((s) => _YouBikeCard(station: s)),
          const SizedBox(height: 16),
        ]);
      },
    );
  }
}

class _YouBikeDetail extends StatelessWidget {
  final YouBikeStation station;
  const _YouBikeDetail({required this.station});

  @override
  Widget build(BuildContext context) {
    final ratio = station.totalSpaces > 0
        ? station.availableBikes / station.totalSpaces
        : 0.0;
    final barColor = ratio > 0.5
        ? const Color(0xFF16A34A)
        : ratio > 0.2
        ? Colors.orange
        : Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle(title: '即時車位狀況'),
        const SizedBox(height: 12),

        // Big numbers
        Row(children: [
          Expanded(child: _BigStatCard(
            icon: Icons.directions_bike,
            label: '可借車輛',
            value: '${station.availableBikes}',
            unit: '輛',
            color: const Color(0xFF16A34A),
          )),
          const SizedBox(width: 12),
          Expanded(child: _BigStatCard(
            icon: Icons.local_parking,
            label: '可還空位',
            value: '${station.availableSpaces}',
            unit: '格',
            color: const Color(0xFF2563EB),
          )),
        ]),

        const SizedBox(height: 16),

        // Progress bar
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

        const SizedBox(height: 16),

        if (station.address.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.location_on, size: 14, color: AppTheme.textGrey),
            const SizedBox(width: 4),
            Expanded(child: Text(station.address,
                style: const TextStyle(fontSize: 12, color: AppTheme.textGrey))),
          ]),
          const SizedBox(height: 8),
        ],

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text('資料來源：TDX 運輸資料',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
      ]),
    );
  }
}

class _YouBikeCard extends StatelessWidget {
  final YouBikeStation station;
  const _YouBikeCard({required this.station});

  @override
  Widget build(BuildContext context) {
    final ratio = station.totalSpaces > 0
        ? station.availableBikes / station.totalSpaces
        : 0.0;
    final barColor = ratio > 0.5
        ? const Color(0xFF16A34A)
        : ratio > 0.2
        ? Colors.orange
        : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(station.stationName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (station.address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(station.address,
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio, minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.directions_bike, size: 14, color: barColor),
          const SizedBox(width: 4),
          const Text('可借 ', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          Text('${station.availableBikes}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: barColor)),
          const SizedBox(width: 14),
          const Icon(Icons.local_parking, size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 4),
          const Text('空位 ', style: TextStyle(fontSize: 12, color: AppTheme.textGrey)),
          Text('${station.availableSpaces}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB))),
          const Spacer(),
          Text('/ ${station.totalSpaces} 格',
              style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 公車 Panel
// ─────────────────────────────────────────────────────────────────────────────
class _BusPanel extends StatefulWidget {
  final PlaceModel place;
  const _BusPanel({required this.place});
  @override
  State<_BusPanel> createState() => _BusPanelState();
}

class _BusPanelState extends State<_BusPanel> {
  final _svc = TransportService();
  late Future<List<BusArrival>> _future;

  @override
  void initState() {
    super.initState();
    // 用站牌名稱搜尋，比用路線號碼更有意義
    _future = _svc.getBusArrivals(routeName: widget.place.name);
  }

  void _refresh() => setState(() =>
  _future = _svc.getBusArrivals(routeName: widget.place.name));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BusArrival>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingCell(message: '載入公車即時資料中...');
        }
        if (snap.hasError) {
          return _RetryCell(message: '無法取得公車資料', onRetry: _refresh);
        }
        final buses = snap.data ?? [];
        if (buses.isEmpty) {
          return _RetryCell(
            message: '目前此站無進站資料',
            sub: '可能非服務時段或資料更新中',
            onRetry: _refresh,
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _InfoBanner(
            icon: Icons.directions_bus,
            text: '${widget.place.name} 即將進站路線',
            color: const Color(0xFF0D9488),
          ),
          ...buses.take(10).map((b) => _BusArrivalRow(bus: b)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, size: 15, color: AppTheme.primaryGreen),
              label: const Text('重新整理', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

class _BusArrivalRow extends StatelessWidget {
  final BusArrival bus;
  const _BusArrivalRow({required this.bus});

  @override
  Widget build(BuildContext context) {
    final arriving = bus.estimateTime == '即將進站';
    final noService = bus.estimateTime == '末班已過' || bus.estimateTime == '未發車';
    final color = arriving
        ? Colors.green
        : noService
        ? Colors.grey
        : const Color(0xFF0D9488);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: arriving ? Border.all(color: Colors.green.shade200) : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // 路線號碼 badge
        Container(
          constraints: const BoxConstraints(minWidth: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(bus.routeName,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 12),

        // 終點站 + 方向
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bus.stopName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            Icon(bus.direction == '去程' ? Icons.arrow_forward : Icons.arrow_back,
                size: 11, color: AppTheme.textGrey),
            const SizedBox(width: 3),
            Text(bus.direction,
                style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
            if (bus.plateNumb.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(bus.plateNumb,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textGrey)),
            ],
          ]),
        ])),

        // 到站時間
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (arriving)
              Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.directions_bus, size: 11, color: color)),
            Text(bus.estimateTime,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 火車 Panel
// ─────────────────────────────────────────────────────────────────────────────
class _TrainPanel extends StatefulWidget {
  final PlaceModel place;
  const _TrainPanel({required this.place});
  @override
  State<_TrainPanel> createState() => _TrainPanelState();
}

class _TrainPanelState extends State<_TrainPanel>
    with SingleTickerProviderStateMixin {
  final _svc = TransportService();
  late Future<List<TrainSchedule>> _future;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _future = _svc.getTrainSchedules();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _future = _svc.getTrainSchedules());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // 北上/南下 Tabs
      Container(
        color: Colors.grey.shade50,
        child: TabBar(
          controller: _tab,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: AppTheme.textGrey,
          indicatorColor: const Color(0xFFDC2626),
          tabs: const [
            Tab(icon: Icon(Icons.north, size: 16), text: '北上'),
            Tab(icon: Icon(Icons.south, size: 16), text: '南下'),
          ],
        ),
      ),
      FutureBuilder<List<TrainSchedule>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _LoadingCell(message: '載入台鐵時刻表中...');
          }
          if (snap.hasError) {
            return _RetryCell(message: '無法取得台鐵資料', onRetry: _refresh);
          }
          final all = snap.data ?? [];

          // 依終點站推斷北上/南下
          // 北上：終點在嘉義以北（台北、台中、新竹、基隆、斗六…）
          // 南下：終點在嘉義以南（台南、高雄、屏東…）
          final _northKeywords = ['台北', '台中', '新竹', '基隆', '斗六', '彰化', '豐原', '苗栗', '桃園', '板橋', '松山', '七堵', '樹林'];
          final _southKeywords = ['台南', '高雄', '屏東', '左營', '新左營', '潮州', '枋寮', '善化', '新市', '永康'];

          final north = all.where((t) =>
              _northKeywords.any((k) => t.arrivalStation.contains(k))).toList();
          final south = all.where((t) =>
              _southKeywords.any((k) => t.arrivalStation.contains(k))).toList();
          // 若分不到，就全部顯示在北上
          final northFinal = north.isEmpty && south.isEmpty ? all : north;
          final southFinal = south;

          return SizedBox(
            height: 400, // fixed height for inner tab content
            child: TabBarView(
              controller: _tab,
              children: [
                _TrainList(trains: northFinal, direction: '北上', onRefresh: _refresh),
                _TrainList(trains: southFinal, direction: '南下', onRefresh: _refresh),
              ],
            ),
          );
        },
      ),
    ]);
  }
}

class _TrainList extends StatelessWidget {
  final List<TrainSchedule> trains;
  final String direction;
  final VoidCallback onRefresh;
  const _TrainList({required this.trains, required this.direction, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (trains.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.train_outlined, size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Text('暫無$direction班次', style: const TextStyle(color: AppTheme.textGrey)),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('重新整理'),
          ),
        ]),
      ));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: trains.length,
      itemBuilder: (_, i) => _TrainRow(train: trains[i]),
    );
  }
}

class _TrainRow extends StatelessWidget {
  final TrainSchedule train;
  const _TrainRow({required this.train});

  Color _typeColor(String type) {
    if (type.contains('自強'))                        return const Color(0xFFDC2626);
    if (type.contains('普悠瑪') || type.contains('太魯閣')) return const Color(0xFF00739D);
    if (type.contains('莒光'))                        return const Color(0xFFD97706);
    if (type.contains('區間快'))                      return const Color(0xFF16A34A);
    if (type.contains('區間'))                        return const Color(0xFF6B7280);
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    final col     = _typeColor(train.trainType);
    final delayed = int.tryParse(train.delayTime) ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: delayed > 0 ? Border.all(color: Colors.orange.shade200) : null,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // 車次 + 類型
        SizedBox(width: 56, child: Column(children: [
          Text(train.trainNo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
            child: Text(train.trainType,
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
        ])),

        const SizedBox(width: 12),

        // 始末站 + 時間
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(train.departureStation,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(Icons.arrow_forward, size: 13, color: col),
            ),
            Flexible(
              child: Text(train.arrivalStation,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ]),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.access_time, size: 12, color: AppTheme.textGrey),
            const SizedBox(width: 3),
            Text('${train.departureTime} → ${train.arrivalTime}',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          ]),
        ])),

        // 誤點 / 準點
        if (delayed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(7)),
            child: Column(children: [
              Text('誤點', style: TextStyle(color: Colors.orange.shade800, fontSize: 9)),
              Text('$delayed分',
                  style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7)),
            child: const Column(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 14),
              SizedBox(height: 2),
              Text('準點', style: TextStyle(color: Colors.green, fontSize: 9)),
            ]),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 共用元件
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: AppTheme.textGrey));
}

class _BigStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  const _BigStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(unit, style: TextStyle(fontSize: 13, color: color.withOpacity(0.8))),
        ),
      ]),
    ]),
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: color.withOpacity(0.07),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
    ]),
  );
}

class _LoadingCell extends StatelessWidget {
  final String message;
  const _LoadingCell({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AppTheme.primaryGreen),
      const SizedBox(height: 14),
      Text(message, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
    ])),
  );
}

class _RetryCell extends StatelessWidget {
  final String message;
  final String? sub;
  final VoidCallback onRetry;
  const _RetryCell({required this.message, this.sub, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade200),
      const SizedBox(height: 12),
      Text(message, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
          color: AppTheme.textDark)),
      if (sub != null) ...[
        const SizedBox(height: 4),
        Text(sub!, style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
            textAlign: TextAlign.center),
      ],
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 15),
        label: const Text('重新整理'),
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9)),
      ),
    ])),
  );
}