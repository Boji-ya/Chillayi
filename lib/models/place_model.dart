// lib/models/place_model.dart

class PlaceModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String location;
  final String category;
  final double rating;
  final List<String> tags;
  final double? lat;
  final double? lng;
  // 活動專用欄位
  final String startDate;  // "2026-06-02"
  final String endDate;
  final String price;
  final List<String> images;
  final String url;

  PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.category,
    this.rating = 0,
    this.tags = const [],
    this.lat,
    this.lng,
    this.startDate = '',
    this.endDate = '',
    this.price = '',
    this.images = const [],
    this.url = '',
  });

  factory PlaceModel.fromMap(Map<String, dynamic> map, String id) {
    return PlaceModel(
      id:          id,
      name:        map['name']        ?? '',
      description: map['description'] ?? '',
      imageUrl:    map['imageUrl']    ?? '',
      location:    map['location']    ?? '',
      category:    map['category']    ?? 'attraction',
      rating:      (map['rating']     ?? 4.5).toDouble(),
      tags:        List<String>.from(map['tags'] ?? []),
      lat:         map['lat']?.toDouble(),
      lng:         map['lng']?.toDouble(),
      startDate:   map['startDate']   ?? '',
      endDate:     map['endDate']     ?? '',
      price:       map['price']       ?? '',
      images:      List<String>.from(map['images'] ?? []),
      url:         map['url']         ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name':        name,
      'description': description,
      'imageUrl':    imageUrl,
      'location':    location,
      'category':    category,
      'rating':      rating,
      'tags':        tags,
      'lat':         lat,
      'lng':         lng,
      'startDate':   startDate,
      'endDate':     endDate,
      'price':       price,
      'images':      images,
      'url':         url,
    };
  }
}