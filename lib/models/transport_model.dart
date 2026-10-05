// lib/models/transport_model.dart
class BusRoute {
  final String routeId;
  final String routeName;
  final String departureStop;
  final String destinationStop;
  final String operatorName;
  final bool hasWheelchair;
  final bool hasTPass;

  BusRoute({
    required this.routeId,
    required this.routeName,
    required this.departureStop,
    required this.destinationStop,
    required this.operatorName,
    this.hasWheelchair = false,
    this.hasTPass = false,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final operators = json['Operators'] as List<dynamic>? ?? [];
    final operatorName = operators.isNotEmpty
        ? (operators.first['OperatorName']?['Zh_tw'] as String? ?? '')
        : '';

    return BusRoute(
      routeId: json['RouteUID'] as String? ?? '',
      routeName: json['RouteName']?['Zh_tw'] as String? ?? '',
      departureStop: json['DepartureStopNameZh'] as String? ?? '',
      destinationStop: json['DestinationStopNameZh'] as String? ?? '',
      operatorName: operatorName,
      hasWheelchair: (json['HasLiftOrRamp'] as int? ?? 0) == 1,
      hasTPass: false,
    );
  }
}
class BusArrival {
  final String routeName;
  final String stopName;
  final String estimateTime;
  final String direction;
  final String plateNumb;

  BusArrival({
    required this.routeName,
    required this.stopName,
    required this.estimateTime,
    required this.direction,
    required this.plateNumb,
  });

  factory BusArrival.fromJson(Map<String, dynamic> json) {
    final stopStatus = json['StopStatus'] as int? ?? 4;

    // 💡 抓取真正的秒數欄位：EstimateTime
    final estimateTime = json['EstimateTime'] as int?;

    String timeStr;
    switch (stopStatus) {
      case 0:
      // 狀態 0 (正常營運) 時，才去判斷秒數
        if (estimateTime == null) {
          timeStr = '即將進站';
        } else {
          final minutes = (estimateTime / 60).floor(); // 換算成分鐘
          timeStr = minutes <= 1 ? '即將進站' : '$minutes 分鐘';
        }
        break;
      case 1:  timeStr = '尚未發車';   break;
      case 2:  timeStr = '交管不停靠'; break;
      case 3:  timeStr = '末班已過';   break;
      default: timeStr = '今日未營運'; break; // 狀態 4 或其他異常情況
    }

    return BusArrival(
      routeName:    json['RouteName']?['Zh_tw'] as String? ?? '',
      stopName:     json['StopName']?['Zh_tw']  as String? ?? '',
      estimateTime: timeStr,
      direction:    (json['Direction'] as int?) == 0 ? '去程' : '返程',
      plateNumb:    json['PlateNumb']           as String? ?? '',
    );
  }

}
class BusStop {
  final String stopUID;
  final String stopName;
  final String address;
  final double lat;
  final double lng;

  BusStop({
    required this.stopUID,
    required this.stopName,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      stopUID:   json['StopUID']  as String? ?? '',
      stopName:  json['StopName']?['Zh_tw'] as String? ?? '',
      address:   json['StopAddress'] as String? ?? '',
      lat: (json['StopPosition']?['PositionLat'] as num?)?.toDouble() ?? 0,
      lng: (json['StopPosition']?['PositionLon'] as num?)?.toDouble() ?? 0,
    );
  }
}
class TrainSchedule {
  final String trainNo;
  final String trainType;
  final String departureStation;
  final String arrivalStation;
  final String departureTime;
  final String arrivalTime;
  final String delayTime;

  TrainSchedule({
    required this.trainNo,
    required this.trainType,
    required this.departureStation,
    required this.arrivalStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.delayTime,
  });

  factory TrainSchedule.fromJson(Map<String, dynamic> json) {
    return TrainSchedule(
      trainNo: json['TrainNo'] ?? '',
      trainType: json['TrainTypeName']?['Zh_tw'] ?? '',
      departureStation: json['OriginStopName']?['Zh_tw'] ?? '',
      arrivalStation: json['DestinationStopName']?['Zh_tw'] ?? '',
      departureTime: json['DepartureTime'] ?? '',
      arrivalTime: json['ArrivalTime'] ?? '',
      delayTime: json['DelayTime']?.toString() ?? '0',
    );
  }
}

class YouBikeStation {
  final String stationId;
  final String stationName;
  final String address;
  final int availableBikes;
  final int availableSpaces;
  final int totalSpaces;
  final double lat;
  final double lng;

  YouBikeStation({
    required this.stationId,
    required this.stationName,
    required this.address,
    required this.availableBikes,
    required this.availableSpaces,
    required this.totalSpaces,
    required this.lat,
    required this.lng,
  });

  factory YouBikeStation.fromJson(Map<String, dynamic> json) {
    return YouBikeStation(
      stationId: json['StationUID'] ?? json['sno'] ?? '',
      stationName: json['StationName']?['Zh_tw'] ?? json['sna'] ?? '',
      address: json['StationAddress']?['Zh_tw'] ?? json['ar'] ?? '',
      availableBikes: int.tryParse(json['AvailableRentBikes']?.toString() ?? json['sbi']?.toString() ?? '0') ?? 0,
      availableSpaces: int.tryParse(json['AvailableReturnBikes']?.toString() ?? json['bemp']?.toString() ?? '0') ?? 0,
      totalSpaces: int.tryParse(json['BikesCapacity']?.toString() ?? json['tot']?.toString() ?? '0') ?? 0,
      lat: double.tryParse(json['StationPosition']?['PositionLat']?.toString() ?? json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['StationPosition']?['PositionLon']?.toString() ?? json['lng']?.toString() ?? '0') ?? 0,
    );
  }
}

class MissionModel {
  final String id;
  final String title;
  final String description;
  final int points;
  final String type;
  bool isCompleted;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.type,
    this.isCompleted = false,
  });

  factory MissionModel.fromMap(Map<String, dynamic> map, String id) {
    return MissionModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
      type: map['type'] ?? 'general',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String imageUrl;
  final String category;

  ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  factory ShopItem.fromMap(Map<String, dynamic> map, String id) {
    return ShopItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: map['price'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? 'general',
    );
  }
}
