// lib/widgets/shared_widgets.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/favorites_service.dart';
import '../pages/detail_page.dart';
import '../pages/map_page.dart';

// ── Place Card ────────────────────────────────────────────────────────────────
class PlaceCard extends StatelessWidget {
  final PlaceModel place;
  final bool horizontal;
  const PlaceCard({super.key, required this.place, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final color = catColor(place.category);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => DetailPage(place: place))),
      child: Container(
        width: horizontal ? 200 : double.infinity,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            CachedNetworkImage(
              imageUrl: place.imageUrl,
              height: horizontal ? 120 : 140,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: horizontal ? 120 : 140,
                  color: color.withOpacity(0.15),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorWidget: (_, __, ___) => Container(
                  height: horizontal ? 120 : 140,
                  color: color.withOpacity(0.1),
                  child: Icon(catIcon(place.category), color: color.withOpacity(0.4), size: 40)),
            ),
            Positioned(top: 8, right: 8,
              child: Consumer<FavoritesService>(builder: (_, fav, __) => GestureDetector(
                onTap: () => fav.toggle(place.id),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    fav.isFavorite(place.id) ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: fav.isFavorite(place.id) ? Colors.red : Colors.grey,
                  ),
                ),
              )),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.location_on, size: 11, color: color),
                const SizedBox(width: 2),
                Expanded(child: Text(place.location,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star, size: 12, color: AppTheme.amber),
                const SizedBox(width: 2),
                Text(place.rating.toString(),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textGrey, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      if (onSeeAll != null)
        TextButton(onPressed: onSeeAll,
            child: const Text('查看全部', style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13))),
    ]);
  }
}

// ── Category Button ───────────────────────────────────────────────────────────
class CategoryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const CategoryButton(
      {super.key, required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
      ]),
    );
  }
}

// ── Loading Shimmer Grid ──────────────────────────────────────────────────────
class LoadingGrid extends StatelessWidget {
  const LoadingGrid({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, childAspectRatio: 0.78, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          Expanded(flex: 3, child: Container(decoration: BoxDecoration(
              color: AppTheme.accentGreen.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16))))),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 12, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(height: 10, width: 80, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
            ]),
          )),
        ]),
      ),
    );
  }
}
