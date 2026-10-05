// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/place_model.dart';
import '../models/transport_model.dart';

import 'dart:convert';
import 'package:flutter/services.dart';


class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 載入 JSON 資料（快取，只讀一次）──────────────────────────────────────
  static Map<String, dynamic>? _cachedData;

  static Future<Map<String, dynamic>> _loadSeedData() async {
    if (_cachedData != null) return _cachedData!;
    final raw = await rootBundle.loadString('assets/data/seed_data.json');
    _cachedData = json.decode(raw) as Map<String, dynamic>;
    return _cachedData!;
  }

  // ── 靜態筆數 ────────────────────────────────────────────────────────────
  static Future<int> get localAttractionCount async =>
      ((await _loadSeedData())['places'] as List).length;
  static Future<int> get localRestaurantCount async =>
      ((await _loadSeedData())['restaurants'] as List).length;
  static Future<int> get localHotelCount async =>
      ((await _loadSeedData())['hotels'] as List).length;
  static Future<int> get localEventCount async =>
      ((await _loadSeedData())['events'] as List).length;
  static Future<int> get localTransportCount async =>
      ((await _loadSeedData())['transport_stops'] as List).length;

  // ── 取得 Firestore 各 collection 目前筆數 ──────────────────────────────
  Future<Map<String, int>> getCollectionCounts() async {
    final cols = ['places', 'restaurants', 'hotels', 'events', 'transport_stops', 'missions', 'shops'];
    final result = <String, int>{};
    for (final col in cols) {
      try {
        final snap = await _db.collection(col).count().get();
        result[col] = snap.count ?? 0;
      } catch (_) {
        try {
          final snap = await _db.collection(col).get();
          result[col] = snap.docs.length;
        } catch (_) {
          result[col] = -1;
        }
      }
    }
    return result;
  }

  // ── 查詢 ──────────────────────────────────────────────────────────────
  Future<List<PlaceModel>> getPlaces({String? category}) async {
    Query query = _db.collection('places_test');
    if (category != null) query = query.where('category', isEqualTo: category);
    final snap = await query.get();
    return snap.docs
        .map((d) => PlaceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<List<PlaceModel>> getRestaurants() async {
    final snap = await _db.collection('restaurants_test').get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['category'] ??= 'restaurant';
      return PlaceModel.fromMap(data, d.id);
    }).toList();
  }

  Future<List<PlaceModel>> getHotels() async {
    final snap = await _db.collection('hotels_test').get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['category'] = 'hotel';
      return PlaceModel.fromMap(data, d.id);
    }).toList();
  }

  Future<List<PlaceModel>> getEvents() async {
    final snap = await _db.collection('events_test').get();
    final list = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['category'] = 'event';
      return PlaceModel.fromMap(data, d.id);
    }).toList();

    // client-side 依 startDate 由新到舊排序（"2026-06-02" 格式字串可直接比較）
    list.sort((a, b) => b.startDate.compareTo(a.startDate));

    return list;
  }
  Future<List<PlaceModel>> getTransportStops() async {
    final snap = await _db.collection('transport_stops').get();
    return snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data() as Map);
      data['category'] = 'transport';
      return PlaceModel.fromMap(data, d.id);
    }).toList();
  }

  Future<void> ratePlace(String placeId, String collection, double newScore, double oldRating, int oldCount) async {
    final ref = _db.collection(collection).doc(placeId);
    final newCount  = oldCount + 1;
    final newRating = ((oldRating * oldCount) + newScore) / newCount;

    await ref.update({
      'rating':      double.parse(newRating.toStringAsFixed(1)),
      'ratingCount': newCount,
    });
  }
  String collectionForCategory(String category) {
    if (category.startsWith('restaurant')) return 'restaurants_test';
    if (category == 'hotel')               return 'hotels_test';
    if (category == 'event')               return 'events_test';
    return 'places_test';
  }
  Future<PlaceModel?> getPlaceById(String id) async {
    final colCategory = <String, String?>{
      'places_test': null,
      'places': null,
      'restaurants_test': 'restaurant',
      'restaurants': 'restaurant',
      'hotels_test': 'hotel',
      'hotels': 'hotel',
      'events': 'event',
      'transport_stops': 'transport',
    };
    for (final entry in colCategory.entries) {
      try {
        final doc = await _db.collection(entry.key).doc(id).get();
        if (doc.exists) {
          final data = Map<String, dynamic>.from(doc.data()!);
          if (entry.value != null) data['category'] = entry.value;
          return PlaceModel.fromMap(data, doc.id);
        }
      } catch (_) {}
    }
    return null;
  }

  // ── 收藏 ────────────────────────────────────────────────────────────
  Future<List<String>> getFavorites(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return List<String>.from(doc.data()?['favorites'] ?? []);
  }

  Future<void> addFavorite(String uid, String placeId) async {
    await _db.collection('users').doc(uid).update({
      'favorites': FieldValue.arrayUnion([placeId]),
    });
  }

  Future<void> removeFavorite(String uid, String placeId) async {
    await _db.collection('users').doc(uid).update({
      'favorites': FieldValue.arrayRemove([placeId]),
    });
  }

  // ── 批次讀取地標資料（給收藏地圖用）────────────────────────────────────
  /// 傳入收藏的 place id 列表，從多個 collection 查出 PlaceModel
  Future<List<PlaceModel>> getPlacesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final collections = {
      'places_test': null as String?,
      'places': null as String?,
      'restaurants_test': 'restaurant',
      'restaurants': 'restaurant',
      'hotels_test': 'hotel',
      'hotels': 'hotel',
      'events': 'event',
      'transport_stops': 'transport',
    };

    final results = <PlaceModel>[];
    final remaining = Set<String>.from(ids);

    for (final entry in collections.entries) {
      if (remaining.isEmpty) break;
      // Firestore whereIn supports max 30 items
      final chunks = _chunk(remaining.toList(), 30);
      for (final chunk in chunks) {
        try {
          final snap = await _db
              .collection(entry.key)
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final data = Map<String, dynamic>.from(doc.data() as Map);
            if (entry.value != null) data['category'] = entry.value;
            results.add(PlaceModel.fromMap(data, doc.id));
            remaining.remove(doc.id);
          }
        } catch (_) {}
      }
    }
    return results;
  }

  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
    }
    return chunks;
  }

  // ── 任務 ─────────────────────────────────────────────────────────────
  Future<List<MissionModel>> getMissions() async {
    final snap = await _db.collection('missions').get();
    return snap.docs.map((d) => MissionModel.fromMap(d.data(), d.id)).toList();
  }

  Future<void> completeMission(String uid, String missionId, int points) async {
    await _db.collection('users').doc(uid).update({
      'completedMissions': FieldValue.arrayUnion([missionId]),
      'points': FieldValue.increment(points),
    });
  }

  // ── 商店 ─────────────────────────────────────────────────────────────
  Future<List<ShopItem>> getShopItems() async {
    final snap = await _db.collection('shops').get();
    return snap.docs.map((d) => ShopItem.fromMap(d.data(), d.id)).toList();
  }
  Future<List<Map<String, dynamic>>> getRedemptions(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('redemptions')
        .orderBy('redeemedAt', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }
  /// 兌換商品。成功回傳 null，失敗回傳錯誤訊息。
  Future<String?> redeemItem(String uid, ShopItem item, int currentPoints) async {
    if (currentPoints < item.price) return '積分不足，無法兌換';
    try {
      // 使用 transaction 確保原子性
      await _db.runTransaction((txn) async {
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await txn.get(userRef);
        final pts = (userSnap.data()?['points'] ?? 0) as int;
        if (pts < item.price) throw Exception('積分不足');

        // 扣除積分
        txn.update(userRef, {'points': FieldValue.increment(-item.price)});

        // 記錄兌換歷史
        final redeemRef = _db.collection('users').doc(uid)
            .collection('redemptions')
            .doc();
        txn.set(redeemRef, {
          'itemId': item.id,
          'itemName': item.name,
          'points': item.price,
          'redeemedAt': FieldValue.serverTimestamp(),
        });
      });
      return null; // success
    } catch (e) {
      return '兌換失敗：$e';
    }
  }

  // ── 強制重置並上傳所有資料 ────────────────────────────────────────────
  Future<String> seedInitialData() async {
    final data = await _loadSeedData();

    final collections = <String, List<Map<String, dynamic>>>{
      'places':          _castList(data['places']),
      'restaurants':     _castList(data['restaurants']),
      'hotels':          _castList(data['hotels']),
      'events':          _castList(data['events']),
      'transport_stops': _castList(data['transport_stops']),
    };

    int total = 0;
    for (final entry in collections.entries) {
      final existing = await _db.collection(entry.key).get();
      if (existing.docs.isNotEmpty) {
        for (int i = 0; i < existing.docs.length; i += 400) {
          final batch = _db.batch();
          final chunk = existing.docs.skip(i).take(400);
          for (final doc in chunk) batch.delete(doc.reference);
          await batch.commit();
        }
      }

      final writeBatch = _db.batch();
      for (final item in entry.value) {
        writeBatch.set(_db.collection(entry.key).doc(), item);
      }
      await writeBatch.commit();
      total += entry.value.length;
    }

    final mExisting = await _db.collection('missions').limit(1).get();
    if (mExisting.docs.isEmpty) {
      final batch = _db.batch();
      for (final m in _castList(data['missions'])) {
        batch.set(_db.collection('missions').doc(), m);
      }
      for (final s in _castList(data['shops'])) {
        batch.set(_db.collection('shops').doc(), s);
      }
      await batch.commit();
    }

    return '已成功上傳 $total 筆地點資料到 Firestore（從 JSON 讀取）';
  }

  Future<String> migrateLatLng() async {
    final data = await _loadSeedData();
    final latLngMap = <String, Map<String, dynamic>>{};

    for (final key in ['places', 'restaurants', 'hotels', 'events', 'transport_stops']) {
      for (final item in _castList(data[key])) {
        if (item['lat'] != null && item['lng'] != null) {
          latLngMap[item['name'] as String] = {
            'lat': item['lat'],
            'lng': item['lng'],
            'category': item['category'],
          };
        }
      }
    }

    final collections = ['places', 'restaurants', 'hotels', 'events', 'transport_stops'];
    int updated = 0;

    for (final col in collections) {
      final snap = await _db.collection(col).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final name = d['name'] as String?;
        final hasCoords = d['lat'] != null && d['lng'] != null;
        if (!hasCoords && name != null && latLngMap.containsKey(name)) {
          await doc.reference.update(latLngMap[name]!);
          updated++;
        }
      }
    }

    return '已補齊 $updated 筆文件的座標資料';
  }

  List<Map<String, dynamic>> _castList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }
}