import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

Future<void> backupFirestore() async {
final firestore = FirebaseFirestore.instance;

// 你要備份的 collection
final collections = [
'places',
'news',
'users',
  'events',
  'hotels',
  'missions',
  'restaurants',
  'shops',
  'transport_stops',
];

Map<String, dynamic> backupData = {};

for (final col in collections) {
final snapshot =
await firestore.collection(col).get();

backupData[col] = snapshot.docs
    .map((doc) => {
'id': doc.id,
...doc.data(),
})
    .toList();
}

// 轉 JSON
final jsonString =
const JsonEncoder.withIndent('  ')
    .convert(backupData);

// 存檔
  final dir = await getApplicationDocumentsDirectory();

final file = File(
'${dir.path}/firebase_backup.json');

await file.writeAsString(jsonString);

print('✅ 備份完成');
print(file.path);
}

