// lib/services/favorites_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class FavoritesService extends ChangeNotifier {
  final FirestoreService _db = FirestoreService();
  Set<String> _favorites = {};
  Set<String> get favorites => _favorites;

  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final list = await _db.getFavorites(uid);
    _favorites = list.toSet();
    notifyListeners();
  }

  Future<void> toggle(String placeId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_favorites.contains(placeId)) {
      _favorites.remove(placeId);
      await _db.removeFavorite(uid, placeId);
    } else {
      _favorites.add(placeId);
      await _db.addFavorite(uid, placeId);
    }
    notifyListeners();
  }
}
