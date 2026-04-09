import 'package:cloud_firestore/cloud_firestore.dart';

class BossModel {
  final String id; // e.g., "boss_2026_03_09" which based on the Monday of that week
  final String name;
  final int maxHp;
  final int currentHp;
  final bool isDefeated;
  final DateTime startDate;
  final DateTime endDate;

  BossModel({
    required this.id,
    required this.name,
    this.maxHp = 1000,
    required this.currentHp,
    this.isDefeated = false,
    required this.startDate,
    required this.endDate,
  });

  factory BossModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BossModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown Boss',
      maxHp: data['maxHp'] ?? 1000,
      currentHp: data['currentHp'] ?? 1000,
      isDefeated: data['isDefeated'] ?? false,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'maxHp': maxHp,
      'currentHp': currentHp,
      'isDefeated': isDefeated,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }
}