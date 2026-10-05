// lib/services/auth_service.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  AuthService() {
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _loadUserModel(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(doc.data()!, uid);
      }
    } catch (e) {
      debugPrint('Error loading user model: $e');
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    }
  }

  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = UserModel(
        uid: credential.user!.uid,
        username: username.trim(),
        email: email.trim(),
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(user.toMap());

      await credential.user!.updateDisplayName(username.trim());
      _userModel = user;
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    }
  }

  /// 寄送重設密碼 Email。成功回傳 null，失敗回傳錯誤訊息。
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _handleAuthError(e);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }

  Future<void> refreshUserModel() async {
    if (currentUser != null) {
      await _loadUserModel(currentUser!.uid);
      notifyListeners();
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '找不到此帳號，請確認 Email 是否正確';
      case 'wrong-password':
        return '密碼錯誤，請重新輸入';
      case 'email-already-in-use':
        return '此 Email 已被使用';
      case 'weak-password':
        return '密碼強度不足，至少需要 6 個字元';
      case 'invalid-email':
        return '無效的 Email 格式';
      case 'too-many-requests':
        return '登入嘗試次數過多，請稍後再試';
      case 'invalid-credential':
        return '帳號或密碼錯誤，請重新確認';
      default:
        return '發生錯誤：${e.message}';
    }
  }
}