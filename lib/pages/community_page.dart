// lib/pages/community_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/community_service.dart';
import 'dart:convert';

// ── Blue colour palette ────────────────────────────────────────────────────────
class _Blue {
  static const c50  = Color(0xFFE6F1FB);
  static const c100 = Color(0xFFB5D4F4);
  static const c200 = Color(0xFF85B7EB);
  static const c400 = Color(0xFF378ADD);
  static const c600 = Color(0xFF185FA5);
  static const c800 = Color(0xFF0C447C);
  static const c900 = Color(0xFF042C53);
}

// ── Page ──────────────────────────────────────────────────────────────────────
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<Map<String, dynamic>> _trendingTags = [];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    final tags = await CommunityService.getTrendingTags();
    if (mounted) setState(() => _trendingTags = tags);
  }

  void _openSearch() {
    showSearch(context: context, delegate: _PostSearchDelegate());
  }

  Future<void> _openCreatePost() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreatePostSheet(filters: ['景點', '美食', '住宿', '交通']),
    );
    if (created == true) _loadTrending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '社群',
          style: TextStyle(color: _Blue.c900, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          _AppBarBtn(
            icon: Icons.search_rounded,
            bg: _Blue.c50,
            iconColor: _Blue.c600,
            onTap: _openSearch,
          ),
          const SizedBox(width: 8),
          _AppBarBtn(
            icon: Icons.add_rounded,
            bg: _Blue.c400,
            iconColor: Colors.white,
            onTap: _openCreatePost,
          ),
          const SizedBox(width: 14),
        ],
      ),
      // ── Feed (Now elevated to body directly) ────────────────────────
      body: StreamBuilder<List<PostModel>>(
        stream: CommunityService.postsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗：${snapshot.error}'));
          }

          final posts = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _loadTrending,
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: posts.length + 2, // +1 stories, +1 trending
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                if (i == 0) return const _StoryRow();
                if (i == posts.length + 1) {
                  return _TrendingCard(tags: _trendingTags);
                }
                return _PostCard(post: posts[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── AppBar icon button ─────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.bg, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ── Story row ──────────────────────────────────────────────────────────────────
class _StoryRow extends StatelessWidget {
  const _StoryRow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PostModel>>(
      // Show the 4 most recent posters as "stories"
      stream: CommunityService.postsStream(),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        // Deduplicate by authorId, take up to 4
        final seen = <String>{};
        final authors = posts.where((p) => seen.add(p.authorId)).take(4).toList();

        return SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add story button
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const _CreatePostSheet(
                    filters: ['景點', '美食', '住宿', '交通'],
                  ),
                ),
                child: _StoryBubble(
                  child: Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _Blue.c50,
                      border: Border.all(color: _Blue.c200, width: 2),
                    ),
                    child: const Icon(Icons.add_rounded, color: _Blue.c400, size: 22),
                  ),
                  label: '新增',
                ),
              ),
              ...authors.map((p) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => _UserPostsPage(authorId: p.authorId, authorName: p.authorName)),
                ),
                child: _StoryBubble(
                  child: Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(p.avatarColorValue),
                      border: Border.all(color: _Blue.c400, width: 2.5),
                    ),
                    child: Center(
                      child: Text(p.authorInitial,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  label: p.authorName,
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final Widget child;
  final String label;
  const _StoryBubble({required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          SizedBox(
            width: 54,
            child: Text(label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _Blue.c800, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Post card ──────────────────────────────────────────────────────────────────
class _PostCard extends StatefulWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _liked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    final uid = CommunityService.currentUser?.uid ?? '';
    _liked = widget.post.likedBy.contains(uid);
    _likeCount = widget.post.likes;
  }

  Future<void> _toggleLike() async {
    // Optimistic update
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    try {
      await CommunityService.toggleLike(widget.post);
    } catch (_) {
      // Revert on error
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
    }
  }

  Color get _tagColor {
    switch (widget.post.tag) {
      case '美食': return const Color(0xFFEAF3DE);
      case '住宿': return const Color(0xFFFFF3E0);
      case '交通': return const Color(0xFFF3E5F5);
      default: return _Blue.c50;
    }
  }

  Color get _tagTextColor {
    switch (widget.post.tag) {
      case '美食': return const Color(0xFF3B6D11);
      case '住宿': return const Color(0xFFE65100);
      case '交通': return const Color(0xFF6A1B9A);
      default: return _Blue.c800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E5F5), width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (post.imageUrl != null)
            post.imageUrl!.startsWith('data:')
                ? Image.memory(
              base64Decode(post.imageUrl!.split(',')[1]),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            )
                : Image.network(
              post.imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : Container(
                height: 160,
                color: _Blue.c50,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: _Blue.c100,
                child: const Center(child: Icon(Icons.broken_image_outlined, color: _Blue.c400, size: 40)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(post.avatarColorValue),
                    child: Text(post.authorInitial,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Blue.c800)),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.authorName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _Blue.c900)),
                    Text(post.timeAgo,
                        style: const TextStyle(fontSize: 11, color: _Blue.c400)),
                  ]),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: _tagColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(post.tag,
                        style: TextStyle(fontSize: 11, color: _tagTextColor, fontWeight: FontWeight.w500)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(post.content,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF2A3A4A), height: 1.55)),
                const SizedBox(height: 10),
                const Divider(height: 0.5, color: Color(0xFFE2EBF6)),
                const SizedBox(height: 8),
                // Actions
                Row(children: [
                  _ActionBtn(
                    icon: _liked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    label: '$_likeCount',
                    color: _liked ? Colors.red : _Blue.c400,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '${post.comments}',
                    color: _Blue.c400,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _CommentsPage(post: post)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ]),
    );
  }
}

// ── Trending card ──────────────────────────────────────────────────────────────
class _TrendingCard extends StatelessWidget {
  final List<Map<String, dynamic>> tags;
  const _TrendingCard({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E5F5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.trending_up_rounded, size: 16, color: _Blue.c400),
            SizedBox(width: 6),
            Text('熱門話題',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _Blue.c900)),
          ]),
          const SizedBox(height: 8),
          if (tags.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else
            ...tags.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t['tag'] as String,
                      style: const TextStyle(fontSize: 13, color: _Blue.c600, fontWeight: FontWeight.w500)),
                  Text('${t['count']} 則貼文',
                      style: const TextStyle(fontSize: 11, color: _Blue.c400)),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── Create post bottom sheet ───────────────────────────────────────────────────
class _CreatePostSheet extends StatefulWidget {
  final List<String> filters;
  const _CreatePostSheet({required this.filters});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _controller = TextEditingController();
  String? _selectedTag;
  File? _imageFile;
  bool _posting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty || _selectedTag == null) return;
    setState(() => _posting = true);
    try {
      await CommunityService.createPost(
        content: _controller.text.trim(),
        tag: _selectedTag!,
        imageFile: _imageFile,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('發佈失敗：$e')));
        setState(() => _posting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: _Blue.c100, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text('新增貼文', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _Blue.c900)),
          const SizedBox(height: 12),

          // Tag selector
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.filters.map((tag) {
                final active = tag == _selectedTag;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTag = tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? _Blue.c400 : _Blue.c50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : _Blue.c800,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Text field
          TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '分享你的旅遊心得…',
              hintStyle: const TextStyle(color: _Blue.c200),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _Blue.c100),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _Blue.c400),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Image preview
          if (_imageFile != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_imageFile!, height: 100, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _imageFile = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ]),

          const SizedBox(height: 10),
          Row(children: [
            // Image picker button
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _Blue.c50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_outlined, color: _Blue.c400, size: 22),
              ),
            ),
            const Spacer(),
            // Submit
            ElevatedButton(
              onPressed: _posting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Blue.c400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('發佈', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Comments page ──────────────────────────────────────────────────────────────
class _CommentsPage extends StatefulWidget {
  final PostModel post;
  const _CommentsPage({required this.post});

  @override
  State<_CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<_CommentsPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await CommunityService.addComment(widget.post.id, _controller.text.trim());
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('發送失敗：$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('留言', style: TextStyle(color: _Blue.c900, fontWeight: FontWeight.w700, fontSize: 17)),
        iconTheme: const IconThemeData(color: _Blue.c900),
      ),
      body: Column(
        children: [
          // Original post summary
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Text(widget.post.content,
                style: const TextStyle(fontSize: 13, color: Color(0xFF2A3A4A), height: 1.5)),
          ),
          const Divider(height: 0.5, color: Color(0xFFE2EBF6)),

          // Comments list
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: CommunityService.commentsStream(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data ?? [];
                if (comments.isEmpty) {
                  return const Center(child: Text('還沒有留言，來搶沙發！', style: TextStyle(color: _Blue.c400)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _Blue.c100,
                            child: Text(c.authorInitial,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Blue.c800)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.authorName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _Blue.c900)),
                                const SizedBox(height: 2),
                                Text(c.content,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF2A3A4A), height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '留個言吧…',
                    hintStyle: const TextStyle(color: _Blue.c200),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: _Blue.c100),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: _Blue.c400),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _send,
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: _Blue.c400, shape: BoxShape.circle),
                  child: _sending
                      ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Search delegate ────────────────────────────────────────────────────────────
class _PostSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => '搜尋貼文…';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    if (query.isEmpty) return const Center(child: Text('輸入關鍵字搜尋'));
    return StreamBuilder<List<PostModel>>(
      stream: CommunityService.postsStream(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final results = all
            .where((p) => p.content.contains(query) || p.authorName.contains(query) || p.tag.contains(query))
            .toList();
        if (results.isEmpty) return const Center(child: Text('沒有相關貼文'));
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PostCard(post: results[i]),
        );
      },
    );
  }
}

// ── User posts page ────────────────────────────────────────────────────────────
class _UserPostsPage extends StatelessWidget {
  final String authorId;
  final String authorName;
  const _UserPostsPage({required this.authorId, required this.authorName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF4FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(authorName,
            style: const TextStyle(color: _Blue.c900, fontWeight: FontWeight.w700, fontSize: 17)),
        iconTheme: const IconThemeData(color: _Blue.c900),
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: CommunityService.postsStream(),
        builder: (context, snapshot) {
          final posts = (snapshot.data ?? []).where((p) => p.authorId == authorId).toList();
          if (posts.isEmpty) return const Center(child: Text('此用戶還沒有貼文'));
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _PostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}