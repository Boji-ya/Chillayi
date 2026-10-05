// lib/services/community_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorInitial;
  final int avatarColorValue;
  final DateTime createdAt;
  final String tag; // '景點' | '美食' | '住宿' | '交通'
  final String content;
  final String? imageUrl;
  int likes;
  int comments;
  List<String> likedBy; // list of user UIDs

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorInitial,
    required this.avatarColorValue,
    required this.createdAt,
    required this.tag,
    required this.content,
    this.imageUrl,
    this.likes = 0,
    this.comments = 0,
    this.likedBy = const [],
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      authorInitial: d['authorInitial'] ?? '',
      avatarColorValue: d['avatarColorValue'] ?? 0xFFB5D4F4,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tag: d['tag'] ?? '全部',
      content: d['content'] ?? '',
      imageUrl: d['imageUrl'],
      likes: d['likes'] ?? 0,
      comments: d['comments'] ?? 0,
      likedBy: List<String>.from(d['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'authorId': authorId,
    'authorName': authorName,
    'authorInitial': authorInitial,
    'avatarColorValue': avatarColorValue,
    'createdAt': FieldValue.serverTimestamp(),
    'tag': tag,
    'content': content,
    'imageUrl': imageUrl,
    'likes': likes,
    'comments': comments,
    'likedBy': likedBy,
  };

  /// Human-readable relative time
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分鐘前';
    if (diff.inHours < 24) return '${diff.inHours}小時前';
    return '${diff.inDays}天前';
  }
}

class CommentModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorInitial;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorInitial,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      authorInitial: d['authorInitial'] ?? '',
      content: d['content'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class CommunityService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference get _posts => _db.collection('community_posts');

  // ── Current user helpers ───────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static String get _uid => currentUser!.uid;

  // ── Fetch posts (with optional tag filter) ─────────────────────────────────

  static Stream<List<PostModel>> postsStream({String? tag}) {
    Query query = _posts.orderBy('createdAt', descending: true).limit(30);
    if (tag != null && tag != '全部') {
      query = query.where('tag', isEqualTo: tag);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map(PostModel.fromDoc).toList(),
    );
  }

  // ── Create post ────────────────────────────────────────────────────────────

  static Future<void> createPost({
    required String content,
    required String tag,
    File? imageFile,
  }) async {
    final user = currentUser!;
    String? imageUrl;

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }


    final displayName = user.displayName ?? user.email ?? '用戶';
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    await _posts.add(PostModel(
      id: '',
      authorId: _uid,
      authorName: displayName,
      authorInitial: initial,
      avatarColorValue: 0xFF378ADD,
      createdAt: DateTime.now(),
      tag: tag,
      content: content,
      imageUrl: imageUrl,
    ).toMap());
  }

  // ── Toggle like ────────────────────────────────────────────────────────────

  static Future<void> toggleLike(PostModel post) async {
    final uid = _uid;
    final ref = _posts.doc(post.id);
    final liked = post.likedBy.contains(uid);

    await ref.update({
      'likedBy': liked ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      'likes': FieldValue.increment(liked ? -1 : 1),
    });
  }

  // ── Comments ───────────────────────────────────────────────────────────────

  static Stream<List<CommentModel>> commentsStream(String postId) {
    return _posts
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  static Future<void> addComment(String postId, String content) async {
    final user = currentUser!;
    final displayName = user.displayName ?? user.email ?? '用戶';
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    final batch = _db.batch();
    final commentRef = _posts.doc(postId).collection('comments').doc();
    batch.set(commentRef, {
      'authorId': _uid,
      'authorName': displayName,
      'authorInitial': initial,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_posts.doc(postId), {'comments': FieldValue.increment(1)});
    await batch.commit();
  }

  // ── Trending tags ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTrendingTags() async {
    final tags = ['景點', '美食', '住宿', '交通'];
    final results = <Map<String, dynamic>>[];

    for (final tag in tags) {
      final snap = await _posts.where('tag', isEqualTo: tag).count().get();
      results.add({'tag': '#$tag', 'count': snap.count});
    }

    results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return results;
  }
}