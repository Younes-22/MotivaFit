import 'package:cloud_firestore/cloud_firestore.dart';

class Reward {
  final String id;
  final String title;
  final int cost;
  final int requiredLevel; 
  final bool isPreset;

  Reward({
    required this.id,
    required this.title,
    required this.cost,
    this.requiredLevel = 0,
    this.isPreset = false,
  });

  // The list of app rewards
  static List<Reward> get presetRewards => [
    Reward(id: 'avatar_novice', title: 'Green Novice Avatar', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'avatar_blue', title: 'Blue Warrior Avatar', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'avatar_fire', title: 'Crimson Firebender Avatar', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'theme_neon', title: 'Neon Theme', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'avatar_shadow_ninja', title: 'Shadow Ninja Avatar', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'avatar_red_knight', title: 'Red Knight Avatar', cost: 0, requiredLevel: 1, isPreset: true),
    Reward(id: 'theme_retro', title: 'Retro Gaming Theme', cost: 0, requiredLevel: 1, isPreset: true),
  ];

  // Firestore serialization for custom rewards
  factory Reward.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reward(
      id: doc.id,
      title: data['title'] ?? 'Unknown Reward',
      cost: data['cost'] ?? 0,
      requiredLevel: 0, 
      isPreset: false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'cost': cost,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}