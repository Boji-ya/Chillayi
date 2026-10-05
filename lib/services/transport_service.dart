// lib/services/transport_service.dart
//
// ═══════════════════════════════════════════════════════════
//  TDX API 金鑰設定區
//  申請網址：https://tdx.transportdata.tw/
//  步驟：登入 → 會員中心 → API 金鑰管理 → 建立應用程式
// ═══════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/transport_model.dart';

class TransportService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  // 全 App 只存在一個實例，避免多個實例同時打 API 觸發 429
  static final TransportService _instance = TransportService._internal();
  factory TransportService() => _instance;
  TransportService._internal();
  // ──────────────────────────────────────────────────────────────────────────

  // ┌─────────────────────────────────────────────────────┐
  // │  ★ 填入你的 TDX 金鑰（兩個都要填）★                   │
  // └─────────────────────────────────────────────────────┘
  static const String _clientId     = 's1122944-a143250a-e51a-40fc';
  static const String _clientSecret = 'c9f84a8b-a2c6-4d09-b56b-9df07e70d81c';
  // ──────────────────────────────────────────────────────

  static const String _authUrl =
      'https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token';
  static const String _baseUrl = 'https://tdx.transportdata.tw/api/basic';

  String?   _accessToken;
  DateTime? _tokenExpiry;

  // ── In-flight 請求去重 ────────────────────────────────────────────────────
  // 若同一類型的請求已在飛行中，新呼叫直接共用同一個 Future，不重複打 API
  Future<String?>?              _tokenFuture;
  Future<List<BusArrival>>?     _busFuture;
  String?                       _busInflightQuery;
  Future<List<TrainSchedule>>?  _trainFuture;
  Future<List<YouBikeStation>>? _bikeFuture;

  // ── 短期快取（30 秒）────────────────────────────────────────────────────
  // 頁面切換或底部彈窗重開時直接回傳快取，不再打新請求
  static const _cacheTtl = Duration(seconds: 30);

  List<BusArrival>?     _busCache;
  DateTime?             _busCacheTime;
  String?               _busCacheQuery;

  List<TrainSchedule>?  _trainCache;
  DateTime?             _trainCacheTime;

  List<YouBikeStation>? _bikeCache;
  DateTime?             _bikeCacheTime;

  // ── 判斷金鑰是否已設定 ────────────────────────────────────────────────────
  bool get _hasCredentials =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  // ── Token 取得 / 快取（含 in-flight 去重）────────────────────────────────
  Future<String?> _getToken() async {
    if (!_hasCredentials) {
      debugPrint('[TDX] ⚠ 尚未設定金鑰，顯示示範資料');
      return null;
    }

    // Token 仍有效，直接使用
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    // 若已有 token 請求在飛行中，等它完成就好，不重新打
    if (_tokenFuture != null) {
      debugPrint('[TDX] Token 請求去重，等待中...');
      return _tokenFuture;
    }

    _tokenFuture = _fetchToken();
    try {
      final token = await _tokenFuture!;
      return token;
    } finally {
      _tokenFuture = null;
    }
  }

  Future<String?> _fetchToken() async {
    try {
      final resp = await http
          .post(
        Uri.parse(_authUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type':    'client_credentials',
          'client_id':     _clientId,
          'client_secret': _clientSecret,
        },
      )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        _accessToken = body['access_token'] as String;
        _tokenExpiry = DateTime.now()
            .add(Duration(seconds: (body['expires_in'] as int) - 60));
        debugPrint('[TDX] ✓ Token 取得成功');
        return _accessToken;
      }
      debugPrint('[TDX] ✗ Token 失敗 ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[TDX] ✗ Token 例外: $e');
      return null;
    }
  }

  Map<String, String> _headers(String token) => {
    'Authorization':   'Bearer $token',
    'Accept':          'application/json',
    'Accept-Encoding': 'gzip',
  };

  // ── 快取是否仍有效 ────────────────────────────────────────────────────────
  bool _cacheValid(DateTime? t) =>
      t != null && DateTime.now().difference(t) < _cacheTtl;

  // ─────────────────────────────────────────────────────────────────────────
  // 公車：嘉義市公車即時到站
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<BusArrival>> getBusArrivals({String routeName = ''}) async {
    // 快取命中
    if (_cacheValid(_busCacheTime) &&
        _busCache != null &&
        _busCacheQuery == routeName) {
      debugPrint('[TDX Bus] 命中快取');
      return _busCache!;
    }

    // 已有相同查詢在飛行中
    if (_busFuture != null && _busInflightQuery == routeName) {
      debugPrint('[TDX Bus] 請求去重，等待中...');
      return _busFuture!;
    }

    _busInflightQuery = routeName;
    _busFuture = _fetchBus(routeName: routeName);
    try {
      final result = await _busFuture!;
      _busCache      = result;
      _busCacheTime  = DateTime.now();
      _busCacheQuery = routeName;
      return result;
    } finally {
      _busFuture        = null;
      _busInflightQuery = null;
    }
  }

  Future<List<BusArrival>> _fetchBus({String routeName = ''}) async {
    final token = await _getToken();
    if (token == null) return _mockBus(routeName: routeName);

    try {
      const url = '$_baseUrl/v2/Bus/EstimatedTimeOfArrival/City/Chiayi?\$top=1000&\$format=JSON';
      final resp = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      debugPrint('[TDX Bus] HTTP ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        debugPrint('[TDX Bus] 原始筆數: ${data.length}');
        if (data.isEmpty) return _mockBus(routeName: routeName);

        var arrivals = data
            .map((e) => BusArrival.fromJson(e as Map<String, dynamic>))
            .where((b) => b.routeName.isNotEmpty && b.stopName.isNotEmpty)
            .toList();

        debugPrint('[TDX Bus] 過濾後筆數: ${arrivals.length}');    // ← 加這行
        debugPrint('[TDX Bus] 第一筆原始: ${data.first}');

        if (routeName.isNotEmpty) {
          final query = routeName.trim().toLowerCase();
          arrivals = arrivals.where((b) =>
          b.routeName.toLowerCase().contains(query) ||
              b.stopName.toLowerCase().contains(query)).toList();
        }

        return arrivals.isEmpty ? _mockBus(routeName: routeName) : arrivals.take(50).toList();
      }

      if (resp.statusCode == 429) {
        debugPrint('[TDX Bus] 429 限流，回傳快取或示範資料');
        return _busCache ?? _mockBus(routeName: routeName);
      }

      return _mockBus(routeName: routeName);
    } catch (e) {
      debugPrint('[TDX Bus] 例外: $e');
      return _busCache ?? _mockBus(routeName: routeName);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 台鐵：嘉義站今日時刻表
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<TrainSchedule>> getTrainSchedules({
    String stationId = '4080',
  }) async {
    if (_cacheValid(_trainCacheTime) && _trainCache != null) {
      debugPrint('[TDX TRA] 命中快取');
      return _trainCache!;
    }

    if (_trainFuture != null) {
      debugPrint('[TDX TRA] 請求去重，等待中...');
      return _trainFuture!;
    }

    _trainFuture = _fetchTrain(stationId: stationId);
    try {
      final result = await _trainFuture!;
      _trainCache     = result;
      _trainCacheTime = DateTime.now();
      return result;
    } finally {
      _trainFuture = null;
    }
  }

  Future<List<TrainSchedule>> _fetchTrain({String stationId = '4080'}) async {
    final token = await _getToken();
    if (token == null) return _mockTrain();

    try {
      final url = '$_baseUrl/v3/Rail/TRA/DailyStationTimetable/Today/Station/$stationId?\$format=JSON';
      final resp = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      debugPrint('[TDX TRA] HTTP ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final stationTimetables = body['StationTimetables'] as List<dynamic>? ?? [];

        List<TrainSchedule> schedules = [];
        final now = DateTime.now();
        final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        for (var st in stationTimetables) {
          final timetables = st['TimeTables'] as List<dynamic>? ?? [];
          for (var t in timetables) {
            final depTime = t['DepartureTime'] as String? ?? '';
            if (depTime.compareTo(currentTime) >= 0) {
              schedules.add(TrainSchedule(
                trainNo:           t['TrainNo'] as String? ?? '',
                trainType:         t['TrainTypeName']?['Zh_tw'] as String? ?? '台鐵',
                departureStation:  '嘉義',
                arrivalStation:    t['DestinationStationName']?['Zh_tw'] as String? ?? '未知',
                departureTime:     depTime,
                arrivalTime:       t['ArrivalTime'] as String? ?? depTime,
                delayTime:         '0',
              ));
            }
          }
        }

        schedules.sort((a, b) => a.departureTime.compareTo(b.departureTime));
        return schedules.isEmpty ? _mockTrain() : schedules.take(30).toList();
      }

      if (resp.statusCode == 429) {
        debugPrint('[TDX TRA] 429 限流，回傳快取或示範資料');
        return _trainCache ?? _mockTrain();
      }

      debugPrint('[TDX TRA] 錯誤 ${resp.statusCode}');
      return _trainCache ?? _mockTrain();
    } catch (e) {
      debugPrint('[TDX TRA] 例外: $e');
      return _trainCache ?? _mockTrain();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // YouBike：嘉義市站點即時資訊
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<YouBikeStation>> getYouBikeStations() async {
    if (_cacheValid(_bikeCacheTime) && _bikeCache != null) {
      debugPrint('[TDX YouBike] 命中快取');
      return _bikeCache!;
    }

    if (_bikeFuture != null) {
      debugPrint('[TDX YouBike] 請求去重，等待中...');
      return _bikeFuture!;
    }

    _bikeFuture = _fetchBike();
    try {
      final result = await _bikeFuture!;
      _bikeCache     = result;
      _bikeCacheTime = DateTime.now();
      return result;
    } finally {
      _bikeFuture = null;
    }
  }

  Future<List<YouBikeStation>> _fetchBike() async {
    final token = await _getToken();
    if (token == null) return _mockYouBike();

    try {
      final results = await Future.wait([
        http.get(
            Uri.parse('$_baseUrl/v2/Bike/Station/City/Chiayi?\$format=JSON'),
            headers: _headers(token))
            .timeout(const Duration(seconds: 15)),
        http.get(
            Uri.parse('$_baseUrl/v2/Bike/Availability/City/Chiayi?\$format=JSON'),
            headers: _headers(token))
            .timeout(const Duration(seconds: 15)),
      ]);

      final stResp    = results[0];
      final availResp = results[1];

      debugPrint('[TDX YouBike] Station ${stResp.statusCode}, Avail ${availResp.statusCode}');

      // 429 任一個就退回快取
      if (stResp.statusCode == 429 || availResp.statusCode == 429) {
        debugPrint('[TDX YouBike] 429 限流，回傳快取或示範資料');
        return _bikeCache ?? _mockYouBike();
      }

      if (stResp.statusCode == 200 && availResp.statusCode == 200) {
        final List<dynamic> stations = json.decode(stResp.body);
        final List<dynamic> avails   = json.decode(availResp.body);
        if (stations.isEmpty) return _mockYouBike();

        final availMap = <String, Map<String, dynamic>>{
          for (final a in avails)
            (a['StationUID'] as String? ?? ''): a as Map<String, dynamic>,
        };

        final list = stations.map((s) {
          final uid = s['StationUID'] as String? ?? '';
          final a   = availMap[uid] ?? {};
          return YouBikeStation(
            stationId:       uid,
            stationName:     s['StationName']?['Zh_tw'] as String? ?? '未知站點',
            address:         s['StationAddress']?['Zh_tw'] as String? ?? '',
            availableBikes:  a['AvailableRentBikes']  as int? ?? 0,
            availableSpaces: a['AvailableReturnBikes'] as int? ?? 0,
            totalSpaces:     s['BikesCapacity']        as int? ?? 0,
            lat: (s['StationPosition']?['PositionLat'] as num?)?.toDouble() ?? 0,
            lng: (s['StationPosition']?['PositionLon'] as num?)?.toDouble() ?? 0,
          );
        }).where((s) => s.stationName.isNotEmpty).toList();

        return list.isEmpty ? _mockYouBike() : list;
      }

      debugPrint('[TDX YouBike] 錯誤，使用示範資料');
      return _bikeCache ?? _mockYouBike();
    } catch (e) {
      debugPrint('[TDX YouBike] 例外: $e');
      return _bikeCache ?? _mockYouBike();
    }
  }
// ─────────────────────────────────────────────────────────────────────────
  // 公車路線搜尋（依路線號碼或名稱）
  // ─────────────────────────────────────────────────────────────────────────
  List<BusRoute>?     _routeCache;
  DateTime?           _routeCacheTime;
  Future<List<BusRoute>>? _routeFuture;
  static const _routeCacheTtl = Duration(hours: 1);

  bool _routeCacheValid() =>
      _routeCacheTime != null &&
          DateTime.now().difference(_routeCacheTime!) < _routeCacheTtl;

  Future<List<BusRoute>> getBusRoutes({String query = ''}) async {
    // 先確保有全量路線快取
    if (!_routeCacheValid() || _routeCache == null) {
      if (_routeFuture != null) {
        await _routeFuture;
      } else {
        _routeFuture = _fetchAllRoutes();
        try {
          _routeCache = await _routeFuture!;
          _routeCacheTime = DateTime.now();
        } finally {
          _routeFuture = null;
        }
      }
    }

    final all = _routeCache ?? _mockRoutes();
    if (query.isEmpty) return all;

    final q = query.toLowerCase().trim();
    return all.where((r) =>
    r.routeName.toLowerCase().contains(q) ||
        r.departureStop.toLowerCase().contains(q) ||
        r.destinationStop.toLowerCase().contains(q)
    ).toList();
  }

  Future<List<BusRoute>> _fetchAllRoutes() async {
    final token = await _getToken();
    if (token == null) return _mockRoutes();

    try {
      // 同時抓嘉義市 + 嘉義縣
      final results = await Future.wait([
        http.get(
          Uri.parse('$_baseUrl/v2/Bus/Route/City/Chiayi?\$format=JSON&\$top=500'),
          headers: _headers(token),
        ).timeout(const Duration(seconds: 15)),
        http.get(
          Uri.parse('$_baseUrl/v2/Bus/Route/City/ChiayiCounty?\$format=JSON&\$top=500'),
          headers: _headers(token),
        ).timeout(const Duration(seconds: 15)),
      ]);

      final List<BusRoute> routes = [];
      for (final resp in results) {
        debugPrint('[TDX Route] HTTP ${resp.statusCode}');
        if (resp.statusCode == 200) {
          final List<dynamic> data = json.decode(resp.body);
          routes.addAll(data
              .map((e) => BusRoute.fromJson(e as Map<String, dynamic>))
              .where((r) => r.routeName.isNotEmpty));
        }
      }

      // 依路線名稱排序
      routes.sort((a, b) => a.routeName.compareTo(b.routeName));
      debugPrint('[TDX Route] 路線總數: ${routes.length}');
      return routes.isEmpty ? _mockRoutes() : routes;
    } catch (e) {
      debugPrint('[TDX Route] 例外: $e');
      return _routeCache ?? _mockRoutes();
    }
  }

  List<BusRoute> _mockRoutes() => [
    BusRoute(routeId: 'r1', routeName: '7322', departureStop: '嘉義火車站', destinationStop: '中埔', operatorName: '嘉義客運'),
    BusRoute(routeId: 'r2', routeName: 'A01', departureStop: '嘉義火車站', destinationStop: '阿里山', operatorName: '嘉義客運'),
    BusRoute(routeId: 'r3', routeName: '7326', departureStop: '嘉義市區', destinationStop: '太保', operatorName: '嘉義客運'),
    BusRoute(routeId: 'r4', routeName: 'A02', departureStop: '嘉義火車站', destinationStop: '竹崎', operatorName: '嘉義客運'),
    BusRoute(routeId: 'r5', routeName: '7328', departureStop: '嘉義公園', destinationStop: '水上', operatorName: '嘉義客運'),
    BusRoute(routeId: 'r6', routeName: 'B01', departureStop: '嘉義火車站', destinationStop: '布袋', operatorName: '嘉義客運'),
  ];

  // ── 站點快取（長時間，1小時）────────────────────────────────
  static const _stopCacheTtl = Duration(hours: 1);
  List<BusStop>? _stopCache;
  DateTime?      _stopCacheTime;
  Future<List<BusStop>>? _stopFuture;

  bool _stopCacheValid() =>
      _stopCacheTime != null &&
          DateTime.now().difference(_stopCacheTime!) < _stopCacheTtl;

// ─────────────────────────────────────────────────────────────────────────
// 取得嘉義市所有公車站點（含座標）
// ─────────────────────────────────────────────────────────────────────────
  Future<List<BusStop>> getBusStops() async {
    if (_stopCacheValid() && _stopCache != null) {
      debugPrint('[TDX Stop] 命中快取');
      return _stopCache!;
    }
    if (_stopFuture != null) return _stopFuture!;

    _stopFuture = _fetchBusStops();
    try {
      final result = await _stopFuture!;
      _stopCache     = result;
      _stopCacheTime = DateTime.now();
      return result;
    } finally {
      _stopFuture = null;
    }
  }

  Future<List<BusStop>> _fetchBusStops() async {
    final token = await _getToken();
    if (token == null) return _mockStops();

    try {
      const url = '$_baseUrl/v2/Bus/Stop/City/Chiayi?\$format=JSON';
      final resp = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 20));

      debugPrint('[TDX Stop] HTTP ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final stops = data
            .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
            .where((s) => s.stopUID.isNotEmpty && s.lat != 0 && s.lng != 0)
            .toList();
        debugPrint('[TDX Stop] 站點數: ${stops.length}');
        return stops.isEmpty ? _mockStops() : stops;
      }
      return _stopCache ?? _mockStops();
    } catch (e) {
      debugPrint('[TDX Stop] 例外: $e');
      return _stopCache ?? _mockStops();
    }
  }

// ─────────────────────────────────────────────────────────────────────────
// 取得特定站的公車到站資訊（用 StopUID 查詢）
// ─────────────────────────────────────────────────────────────────────────
  Future<List<BusArrival>> getBusArrivalsByStop(String stopUID) async {
    final token = await _getToken();
    if (token == null) return _mockBus();

    try {
      // StopUID 格式例：CYI308319
      final encoded = Uri.encodeComponent("StopUID eq '$stopUID'");
      final url =
          '$_baseUrl/v2/Bus/EstimatedTimeOfArrival/City/Chiayi?\$filter=$encoded&\$format=JSON';

      final resp = await http
          .get(Uri.parse(url), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      debugPrint('[TDX StopArrival] HTTP ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body);
        final arrivals = data
            .map((e) => BusArrival.fromJson(e as Map<String, dynamic>))
            .where((b) =>
        b.routeName.isNotEmpty &&
            b.estimateTime != '末班已過' &&
            b.estimateTime != '資料異常')
            .toList();
        return arrivals;
      }
      return [];
    } catch (e) {
      debugPrint('[TDX StopArrival] 例外: $e');
      return [];
    }
  }

// mock 站點（金鑰未設定時用）
  List<BusStop> _mockStops() => [
    BusStop(stopUID: 'CYI001', stopName: '嘉義火車站',  address: '中山路499號', lat: 23.4789, lng: 120.4409),
    BusStop(stopUID: 'CYI002', stopName: '文化路夜市口', address: '文化路136號', lat: 23.4779, lng: 120.4497),
    BusStop(stopUID: 'CYI003', stopName: '中山公園',    address: '公園街42號',  lat: 23.4802, lng: 120.4486),
    BusStop(stopUID: 'CYI004', stopName: '嘉義市政府',  address: '中山路199號', lat: 23.4801, lng: 120.4564),
    BusStop(stopUID: 'CYI005', stopName: '檜意森活村',  address: '林森東路2號', lat: 23.4801, lng: 120.4491),
  ];
  // ─────────────────────────────────────────────────────────────────────────
  // 手動清除快取（強制重新抓取）
  // ─────────────────────────────────────────────────────────────────────────
  void clearCache() {
    _busCache      = null; _busCacheTime  = null;
    _trainCache    = null; _trainCacheTime = null;
    _bikeCache     = null; _bikeCacheTime  = null;
    debugPrint('[TDX] 快取已清除');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 示範資料（未設定金鑰 or API 失敗時顯示）
  // ─────────────────────────────────────────────────────────────────────────
  bool get isUsingMock => !_hasCredentials;

  List<BusArrival> _mockBus({String routeName = ''}) {
    final all = [
      BusArrival(routeName: '7322', stopName: '嘉義火車站', estimateTime: '3 分鐘',   direction: '去程', plateNumb: 'KKA-001'),
      BusArrival(routeName: 'A01',  stopName: '嘉義火車站', estimateTime: '即將進站', direction: '去程', plateNumb: 'KKA-088'),
      BusArrival(routeName: '7326', stopName: '文化路夜市', estimateTime: '8 分鐘',   direction: '去程', plateNumb: 'KKA-032'),
      BusArrival(routeName: 'A02',  stopName: '中山公園',  estimateTime: '15 分鐘',  direction: '返程', plateNumb: 'KKA-045'),
      BusArrival(routeName: '7322', stopName: '嘉義縣政府', estimateTime: '22 分鐘', direction: '去程', plateNumb: 'KKA-060'),
      BusArrival(routeName: '7328', stopName: '嘉義公園',  estimateTime: '11 分鐘', direction: '去程', plateNumb: 'KKA-077'),
    ];
    if (routeName.isEmpty) return all;
    final filtered = all.where((b) => b.routeName == routeName).toList();
    return filtered.isEmpty ? all : filtered;
  }

  List<TrainSchedule> _mockTrain() {
    final now = DateTime.now();
    String t(int h, int m) {
      final dt = now.add(Duration(hours: h, minutes: m));
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return [
      TrainSchedule(trainNo: '0117', trainType: '自強號', departureStation: '嘉義', arrivalStation: '台北', departureTime: t(0, 10), arrivalTime: t(2, 45), delayTime: '0'),
      TrainSchedule(trainNo: '1103', trainType: '莒光號', departureStation: '嘉義', arrivalStation: '高雄', departureTime: t(0, 25), arrivalTime: t(1, 35), delayTime: '5'),
      TrainSchedule(trainNo: '0119', trainType: '自強號', departureStation: '嘉義', arrivalStation: '台北', departureTime: t(1,  5), arrivalTime: t(3, 40), delayTime: '0'),
      TrainSchedule(trainNo: '0257', trainType: '普悠瑪', departureStation: '嘉義', arrivalStation: '台南', departureTime: t(1, 30), arrivalTime: t(2, 10), delayTime: '0'),
      TrainSchedule(trainNo: '2211', trainType: '區間車', departureStation: '嘉義', arrivalStation: '斗六', departureTime: t(0, 50), arrivalTime: t(1, 30), delayTime: '0'),
    ];
  }

  List<YouBikeStation> _mockYouBike() => [
    YouBikeStation(stationId: 'CYI001', stationName: '嘉義火車站',  address: '嘉義市中山路499號', availableBikes: 8,  availableSpaces: 7,  totalSpaces: 15, lat: 23.4789, lng: 120.4409),
    YouBikeStation(stationId: 'CYI002', stationName: '文化路夜市口', address: '嘉義市文化路136號', availableBikes: 3,  availableSpaces: 12, totalSpaces: 15, lat: 23.4779, lng: 120.4497),
    YouBikeStation(stationId: 'CYI003', stationName: '中山公園',    address: '嘉義市公園街42號',  availableBikes: 11, availableSpaces: 4,  totalSpaces: 15, lat: 23.4802, lng: 120.4486),
    YouBikeStation(stationId: 'CYI004', stationName: '嘉義市政府',  address: '嘉義市中山路199號', availableBikes: 6,  availableSpaces: 9,  totalSpaces: 15, lat: 23.4801, lng: 120.4564),
    YouBikeStation(stationId: 'CYI005', stationName: '檜意森活村',  address: '嘉義市林森東路2號', availableBikes: 0,  availableSpaces: 20, totalSpaces: 20, lat: 23.4801, lng: 120.4491),
  ];
}