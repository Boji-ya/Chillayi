// lib/pages/events_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/firestore_service.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(
          child: FutureBuilder<List<PlaceModel>>(
            future: FirestoreService().getEvents(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
              }
              final all = snap.data ?? [];
              final list = all.where((e) {
                return _query.isEmpty ||
                    e.name.contains(_query) ||
                    e.location.contains(_query) ||
                    e.description.contains(_query);
              }).toList();

              if (list.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.event_busy, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(_query.isEmpty ? '目前尚無活動資訊' : '找不到「$_query」',
                      style: const TextStyle(color: AppTheme.textGrey, fontSize: 15)),
                  if (_query.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: () { setState(() { _query = ''; _searchCtrl.clear(); }); },
                        child: const Text('清除搜尋')),
                  ],
                ]));
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: AppTheme.primaryGreen,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _EventCard(event: list[i]),
                ),
              );
            },
          ),
        ),
      ])),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('嘉義活動', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        const SizedBox(height: 2),
        const Text('探索嘉義市最新活動資訊', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: '搜尋活動名稱、地點...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen, size: 20),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                onTap: () => setState(() { _query = ''; _searchCtrl.clear(); }),
                child: const Icon(Icons.clear, size: 18, color: AppTheme.textGrey))
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ]),
    );
  }
}

// ── Event Card ────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final PlaceModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => _EventDetailPage(event: event))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Stack(children: [
            CachedNetworkImage(
              imageUrl: event.imageUrl,
              height: 165,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 165, color: const Color(0xFF7C3AED).withOpacity(0.15)),
              errorWidget: (_, __, ___) => Container(height: 165, color: const Color(0xFF7C3AED).withOpacity(0.1),
                  child: const Icon(Icons.event, size: 48, color: Color(0xFF7C3AED))),
            ),
            // Gradient
            Positioned.fill(child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)])),
            )),
            // Free badge
            Positioned(top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('免費', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
            // Category badge
            Positioned(top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('活動', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),

          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 4),
                Expanded(child: Text(event.location,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 6),
              if (event.tags.isNotEmpty)
                Wrap(spacing: 6, children: event.tags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tag, style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
                )).toList()),
              const SizedBox(height: 10),
              // Bottom row
              Row(children: [
                Row(children: [
                  const Icon(Icons.star, size: 13, color: AppTheme.amber),
                  const SizedBox(width: 3),
                  Text(event.rating.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('查看詳情', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Event Detail Page ─────────────────────────────────────────────────────────
class _EventDetailPage extends StatelessWidget {
  final PlaceModel event;
  const _EventDetailPage({required this.event});

  @override
  Widget build(BuildContext context) {
    const col = Color(0xFF7C3AED);

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: col,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: event.imageUrl, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: col.withOpacity(0.4)),
                errorWidget: (_, __, ___) => Container(color: col.withOpacity(0.3),
                    child: const Icon(Icons.event, color: Colors.white54, size: 60)),
              ),
              Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54]))),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Tags
              if (event.tags.isNotEmpty)
                Wrap(spacing: 6, children: event.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(tag, style: const TextStyle(fontSize: 12, color: col, fontWeight: FontWeight.w500)),
                )).toList()),
              const SizedBox(height: 14),

              // Title
              Text(event.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 16),

              // Info cards
              _InfoRow(icon: Icons.location_on, label: '活動地點', value: event.location, iconColor: col),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.star, label: '評分', value: event.rating.toString(), iconColor: AppTheme.amber),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.attach_money, label: '費用', value: '免費入場', iconColor: Colors.green),
              const SizedBox(height: 24),

              // Description
              const Text('活動介紹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              Text(
                event.description,
                style: const TextStyle(fontSize: 15, color: AppTheme.textGrey, height: 1.75),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
              const SizedBox(height: 32),

              // CTA
              SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('加入行事曆'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: col,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('分享活動'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: col,
                        side: const BorderSide(color: col),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  )),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _InfoRow({required this.icon, required this.label, required this.value, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
        ]),
      ]),
    );
  }
}