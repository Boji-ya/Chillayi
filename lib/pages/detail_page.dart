// lib/pages/detail_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models/place_model.dart';
import '../services/favorites_service.dart';
import 'map_page.dart';

class DetailPage extends StatelessWidget {
  final PlaceModel place;
  const DetailPage({super.key, required this.place});

  Color get _catColor {
    switch (place.category) {
      case 'restaurant': return const Color(0xFFEA580C);
      case 'hotel': return const Color(0xFF2563EB);
      case 'event': return const Color(0xFF7C3AED);
      case 'transport': return const Color(0xFF0D9488);
      default: return AppTheme.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _catColor;
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: CustomScrollView(slivers: [
        // ─ AppBar with hero image ─
        SliverAppBar(
          expandedHeight: 290,
          pinned: true,
          backgroundColor: color,
          actions: [
            Consumer<FavoritesService>(builder: (_, fav, __) => IconButton(
              icon: Icon(
                fav.isFavorite(place.id) ? Icons.favorite : Icons.favorite_border,
                color: fav.isFavorite(place.id) ? Colors.red.shade300 : Colors.white,
              ),
              onPressed: () => fav.toggle(place.id),
            )),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: place.imageUrl, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: color.withOpacity(0.4)),
                errorWidget: (_, __, ___) => Container(color: color.withOpacity(0.3),
                    child: Icon(catIcon(place.category), color: Colors.white54, size: 60)),
              ),
              Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54]))),
            ]),
          ),
        ),

        // ─ Content ─
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Tags
              if (place.tags.isNotEmpty)
                Wrap(spacing: 6, runSpacing: 6,
                    children: place.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(tag, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
                    )).toList()),
              const SizedBox(height: 14),

              // Title + Rating
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(place.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark))),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, color: AppTheme.amber, size: 16),
                    const SizedBox(width: 3),
                    Text(place.rating.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),

              // Location
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.location_on, color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(place.location,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textDark))),
                ]),
              ),
              const SizedBox(height: 24),

              // Description
              const Text('關於此地',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 12),
              Text(place.description,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textGrey, height: 1.75)),
              const SizedBox(height: 32),

              // Action buttons
              if (place.lat != null && place.lng != null) ...[
                SizedBox(width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final url = 'https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}';
                        try {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } catch (_) {
                          await launchUrl(
                            Uri.parse('https://www.openstreetmap.org/?mlat=${place.lat}&mlon=${place.lng}&zoom=17'),
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('開啟地圖導航'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )),
              ],
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}
