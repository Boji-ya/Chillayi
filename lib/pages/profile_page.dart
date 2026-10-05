// lib/pages/profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/transport_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'dart:convert';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: const Color(0xff8A9A5B),
      body: SingleChildScrollView(
        child: Column(children: [
          // Header Section with Overlapping Stats Card
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Background Image
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 70),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  image: DecorationImage(
                    image: const AssetImage('images/profile.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.4),
                      BlendMode.darken,
                    ),
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('我的', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () => _confirmLogout(context, auth),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  // Avatar — now shows profile picture if available
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? (user.avatarUrl!.startsWith('data:')
                          ? MemoryImage(base64Decode(user.avatarUrl!.split(',')[1]))
                          : NetworkImage(user.avatarUrl!)) as ImageProvider
                          : null,
                      child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                          ? Text(
                        (user?.username ?? '旅').substring(0, 1),
                        style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.username ?? '旅行者',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                ]),
              ),

              // Elevated Stats Card
              Positioned(
                bottom: -40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _StatChip(label: '積分', value: '${user?.points ?? 0}'),
                    Container(height: 40, width: 1, color: Colors.grey.shade200),
                    _StatChip(label: '收藏', value: '${user?.favorites.length ?? 0}'),
                    Container(height: 40, width: 1, color: Colors.grey.shade200),
                    _StatChip(label: '任務', value: '${user?.completedMissions.length ?? 0}'),
                  ]),
                ),
              ),
            ],
          ),

          const SizedBox(height: 64),

          // Menu items Group
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(children: [
                _MenuTile(
                    icon: Icons.emoji_events,
                    label: '任務系統',
                    color: AppTheme.amber,
                    isTop: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MissionsPage()))
                ),
                Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                _MenuTile(
                    icon: Icons.store,
                    label: '商店',
                    color: AppTheme.primaryGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopPage()))
                ),
                Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                _MenuTile(
                    icon: Icons.person_outline,
                    label: '個人資料設定',
                    color: Colors.blue,
                    isBottom: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfilePage()))
                ),
              ]),
            ),
          ),

          const SizedBox(height: 32),
          Text('探索嘉義之旅', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('登出', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text('確定要登出嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Colors.grey.shade600))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            await auth.signOut();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
          },
          child: const Text('登出', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(color: AppTheme.darkGreen, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isTop;
  final bool isBottom;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isTop = false,
    this.isBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(20) : Radius.zero,
          bottom: isBottom ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24)
            ),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ]),
        ),
      ),
    );
  }
}

// ── Edit Profile Page ─────────────────────────────────────────────────────────
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingPhoto = false;
  File? _newPhotoFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().userModel;
    _nameCtrl.text = user?.username ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Pick image from gallery or camera ──────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 40, maxWidth: 300, maxHeight: 300,);
    if (picked != null) {
      setState(() => _newPhotoFile = File(picked.path));
      await _uploadPhoto();
    }
  }

  // ── Upload to Firebase Storage and save URL to Firestore ──────────────────
  Future<void> _uploadPhoto() async {
    if (_newPhotoFile == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUser?.uid;
      if (uid == null) return;

      // Convert to base64 instead of Storage
      final bytes = await _newPhotoFile!.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      // Save to Firestore only
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatarUrl': base64Str});
      await auth.refreshUserModel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('大頭照已更新'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上傳失敗：$e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Show picker source chooser ─────────────────────────────────────────────
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryGreen),
              title: const Text('從相簿選擇'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryGreen),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('名稱不能為空')));
      return;
    }
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'username': name});
        await auth.currentUser!.updateDisplayName(name);
        await auth.refreshUserModel();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已儲存'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('儲存失敗：$e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.userModel;
    final currentPhotoUrl = user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資料設定'),
        backgroundColor: AppTheme.primaryGreen,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('儲存', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      backgroundColor: AppTheme.cream,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 16),

          // ── Avatar with upload button ──────────────────────────────────
          GestureDetector(
            onTap: _uploadingPhoto ? null : _showImageSourceSheet,
            child: Stack(alignment: Alignment.bottomRight, children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
                backgroundImage: _newPhotoFile != null
                    ? FileImage(_newPhotoFile!)
                    : (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                    ? (currentPhotoUrl.startsWith('data:')
                    ? MemoryImage(base64Decode(currentPhotoUrl.split(',')[1]))
                    : NetworkImage(currentPhotoUrl)) as ImageProvider
                    : null),
                child: (_newPhotoFile == null &&
                    (currentPhotoUrl == null || currentPhotoUrl.isEmpty))
                    ? Text(
                  (_nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text
                      : user?.username ?? '旅')
                      .substring(0, 1),
                  style: const TextStyle(
                      fontSize: 40,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold),
                )
                    : null,
              ),
              // Camera button / loading indicator
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: _uploadingPhoto
                    ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            _uploadingPhoto ? '上傳中...' : '點擊更換大頭照',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),

          const SizedBox(height: 32),

          // Fields
          _buildSection('帳號資訊', [
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: user?.email ?? ''),
          ]),

          const SizedBox(height: 16),

          _buildSection('基本資料', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Icon(Icons.person_outline, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('顯示名稱', style: TextStyle(fontSize: 11, color: AppTheme.textGrey)),
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '請輸入您的名稱',
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ])),
              ]),
            ),
          ]),

          const SizedBox(height: 16),

          _buildSection('帳號統計', [
            _InfoRow(icon: Icons.stars, label: '累積積分', value: '${user?.points ?? 0} 點'),
            const Divider(height: 1, indent: 50),
            _InfoRow(icon: Icons.favorite, label: '收藏地點', value: '${user?.favorites.length ?? 0} 處'),
            const Divider(height: 1, indent: 50),
            _InfoRow(icon: Icons.emoji_events, label: '完成任務', value: '${user?.completedMissions.length ?? 0} 項'),
          ]),

          const SizedBox(height: 16),

          _buildSection('安全性', [
            GestureDetector(
              onTap: () => _showChangePassword(context),
              child: const _InfoRow(icon: Icons.lock_outline, label: '修改密碼', value: ''),
            ),
          ]),

          const SizedBox(height: 32),

          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDelete(context, auth),
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              label: const Text('刪除帳號', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textGrey)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
        ),
        child: Column(children: children),
      ),
    ]);
  }

  void _showChangePassword(BuildContext context) {
    final pwCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('修改密碼', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: pwCtrl, obscureText: true,
            decoration: InputDecoration(
              labelText: '新密碼（至少6碼）',
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (pwCtrl.text.trim().length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('密碼至少需要6個字元')));
                  return;
                }
                try {
                  await context.read<AuthService>().currentUser!.updatePassword(pwCtrl.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('密碼已更新'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('請先重新登入再修改密碼'), backgroundColor: Colors.orange));
                }
              },
              child: const Text('確認修改'),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AuthService auth) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('刪除帳號', style: TextStyle(color: Colors.red)),
      content: const Text('此操作無法復原，確定要刪除帳號嗎？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () async {
          try {
            await auth.currentUser!.delete();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
          } catch (e) {
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請先重新登入再刪除帳號'), backgroundColor: Colors.orange));
            }
          }
        }, child: const Text('刪除', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textGrey)),
          if (value.isNotEmpty)
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
        const Spacer(),
        if (value.isEmpty)
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      ]),
    );
  }
}

class _G {
  static const c50  = Color(0xFFEAF3DE);
  static const c100 = Color(0xFFC0DD97);
  static const c200 = Color(0xFF97C459);
  static const c400 = Color(0xFF639922);
  static const c600 = Color(0xFF3B6D11);
  static const c800 = Color(0xFF27500A);
  static const c900 = Color(0xFF173404);
  static const amber     = Color(0xFFBA7517);
  static const amberBg   = Color(0xFFFAEEDA);
  static const amberLight= Color(0xFFFAC775);
  static const pageBg    = Color(0xFFF2F7EC);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MISSIONS PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key});
  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  late Future<List<MissionModel>> _future;
  final _svc = FirestoreService();
  int _tab = 0;

  @override
  void initState() { super.initState(); _future = _svc.getMissions(); }

  @override
  Widget build(BuildContext context) {
    final auth  = context.read<AuthService>();
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _G.pageBg,
      body: FutureBuilder<List<MissionModel>>(
        future: _future,
        builder: (_, snap) {
          final missions   = snap.data ?? [];
          final completed  = auth.userModel?.completedMissions ?? [];
          final donePoints = missions
              .where((m) => completed.contains(m.id))
              .fold<int>(0, (s, m) => s + m.points);

          final filtered = _tab == 1
              ? missions.where((m) => !completed.contains(m.id)).toList()
              : _tab == 2
              ? missions.where((m) =>  completed.contains(m.id)).toList()
              : missions;

          return Column(children: [
            Container(
              color: _G.c600,
              padding: EdgeInsets.fromLTRB(18, topPad + 12, 18, 24),
              child: Column(children: [
                Row(children: [
                  _HeaderBtn(icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  const Text('任務系統',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  const SizedBox(width: 36),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2.5),
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: _G.amberLight, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('本月完成進度', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                      const SizedBox(height: 2),
                      Text('${completed.length} / ${missions.length} 任務',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: missions.isEmpty ? 0 : completed.length / missions.length,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          color: _G.c100,
                          minHeight: 6,
                        ),
                      ),
                    ])),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('+$donePoints',
                          style: const TextStyle(color: _G.amberLight, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('積分', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                    ]),
                  ]),
                ),
              ]),
            ),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _G.pageBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Row(children: [
                      _FilterChip(label: '全部',   active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                      const SizedBox(width: 8),
                      _FilterChip(label: '進行中', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                      const SizedBox(width: 8),
                      _FilterChip(label: '已完成', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
                    ]),
                  ),

                  if (snap.connectionState == ConnectionState.waiting)
                    const Expanded(child: Center(child: CircularProgressIndicator(color: _G.c400)))
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = filtered[i];
                          final isDone = completed.contains(m.id);
                          return _MissionCard(
                            mission: m,
                            isDone: isDone,
                            onComplete: () async {
                              final uid = auth.currentUser?.uid;
                              if (uid == null) return;
                              await _svc.completeMission(uid, m.id, m.points);
                              await auth.refreshUserModel();
                              setState(() => _future = _svc.getMissions());
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('任務完成！獲得 ${m.points} 積分'),
                                  backgroundColor: _G.c600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MissionModel mission;
  final bool isDone;
  final VoidCallback onComplete;
  const _MissionCard({required this.mission, required this.isDone, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDone ? _G.c50 : _G.c200,
          width: isDone ? 0.5 : 1.5,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isDone ? _G.c50 : _G.amberBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.emoji_events_rounded,
            color: isDone ? _G.c600 : _G.amber,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                mission.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDone ? _G.c800.withOpacity(0.5) : _G.c900,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: _G.c400,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDone ? _G.c50 : _G.amberBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isDone ? '完成' : '進行中',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isDone ? _G.c600 : _G.amber,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(mission.description,
              style: TextStyle(fontSize: 11, color: _G.c600.withOpacity(0.7))),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.star_rounded, color: _G.amber, size: 14),
            const SizedBox(width: 3),
            Text('+${mission.points} 積分',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _G.amber)),
            const Spacer(),
            if (!isDone)
              GestureDetector(
                onTap: onComplete,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _G.c600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('完成',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHOP PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  @override
  Widget build(BuildContext context) {
    final auth   = context.read<AuthService>();
    final points = auth.userModel?.points ?? 0;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _G.pageBg,
      body: Column(children: [
        Container(
          color: _G.c600,
          padding: EdgeInsets.fromLTRB(18, topPad + 12, 18, 24),
          child: Column(children: [
            Row(children: [
              _HeaderBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
              const Spacer(),
              const Text('積分商店',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: _G.amberLight, size: 15),
                  const SizedBox(width: 4),
                  Text('$points', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('可用積分', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                  const SizedBox(height: 2),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$points',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('點', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ),
                  ]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Text('已兌換', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                    const SizedBox(height: 2),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService().getRedemptions(auth.currentUser!.uid),
                      builder: (_, snap) => Text(
                        '${snap.data?.length ?? 0} 件',
                        style: const TextStyle(color: _G.amberLight, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),

        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: _G.pageBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FutureBuilder<List<ShopItem>>(
              future: FirestoreService().getShopItems(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _G.c400));
                }
                final items = snap.data ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                  children: [
                    // ── Shop grid ──────────────────────────────────────
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.76,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (_, i) {
                        final item   = items[i];
                        final canBuy = points >= item.price;
                        return _ShopCard(item: item, canBuy: canBuy, onTap: () async {
                          if (!canBuy) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('積分不足！需要 ${item.price} 點，目前只有 $points 點'),
                                backgroundColor: Colors.red.shade600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('確認兌換', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: Column(mainAxisSize: MainAxisSize.min, children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'images/${item.imageUrl}.jpg',
                                    height: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 100,
                                      color: _G.c50,
                                      child: const Icon(Icons.shopping_bag_outlined, color: _G.c400, size: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.star_rounded, color: _G.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text('${item.price} 點', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _G.amber)),
                                ]),
                                const SizedBox(height: 8),
                                Text('兌換後剩餘：${points - item.price} 點',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              ]),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                    child: Text('取消', style: TextStyle(color: Colors.grey.shade600))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _G.c600,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('確認兌換', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;

                          final uid = auth.currentUser?.uid;
                          if (uid == null) return;
                          final error = await FirestoreService().redeemItem(uid, item, points);
                          if (!context.mounted) return;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.red.shade600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          } else {
                            await auth.refreshUserModel();
                            if (!context.mounted) return;
                            setState(() {}); // refresh redemption count
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('🎉 成功兌換「${item.name}」！'),
                              backgroundColor: _G.c600,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ));
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    // ── Redemption history ─────────────────────────────
                    const Text('已兌換紀錄',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _G.c900)),
                    const SizedBox(height: 10),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService().getRedemptions(auth.currentUser!.uid),
                      builder: (_, rSnap) {
                        if (rSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: _G.c400));
                        }
                        final redemptions = rSnap.data ?? [];
                        if (redemptions.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('尚未兌換任何商品',
                                  style: TextStyle(color: _G.c400, fontSize: 13)),
                            ),
                          );
                        }
                        return Column(
                          children: redemptions.map((r) {
                            final ts = r['redeemedAt'] as Timestamp?;
                            final date = ts != null
                                ? '${ts.toDate().year}/${ts.toDate().month}/${ts.toDate().day}'
                                : '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _G.c50),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: _G.amberBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.card_giftcard, color: _G.amber, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(r['itemName'] ?? '',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _G.c900)),
                                  if (date.isNotEmpty)
                                    Text(date, style: const TextStyle(fontSize: 11, color: _G.c400)),
                                ])),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _G.amberBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.star_rounded, color: _G.amber, size: 12),
                                    const SizedBox(width: 3),
                                    Text('-${r['points']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _G.amber)),
                                  ]),
                                ),
                              ]),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopItem item;
  final bool canBuy;
  final VoidCallback onTap;
  const _ShopCard({required this.item, required this.canBuy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _G.c100, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ClipRRect(
            child: Image.asset(
              'images/${item.imageUrl}.jpg',
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 110,
                color: _G.c50,
                child: const Center(
                  child: Icon(Icons.shopping_bag_outlined, color: _G.c400, size: 36),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _G.c600, borderRadius: BorderRadius.circular(20)),
              child: const Text('熱門', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _G.c900),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(children: [
                const Icon(Icons.star_rounded, color: _G.amber, size: 14),
                const SizedBox(width: 3),
                Text('${item.price}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _G.amber)),
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: canBuy ? _G.c600 : _G.c50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '兌換',
                      style: TextStyle(
                        color: canBuy ? Colors.white : _G.c400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _G.c600 : _G.c50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _G.c800,
          ),
        ),
      ),
    );
  }
}