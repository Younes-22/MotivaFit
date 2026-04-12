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
    this.isPreset = true, 
  });

  // The list of app rewards
  static List<Reward> get presetRewards => [
    Reward(id: 'avatar_green_novice', title: 'Green Novice', cost: 10, requiredLevel: 1),
    Reward(id: 'avatar_blue_warrior', title: 'Blue Warrior Avatar', cost: 20, requiredLevel: 2),
    Reward(id: 'avatar_crimson_firebender', title: 'Crimson Firebender', cost: 20, requiredLevel: 3),
    Reward(id: 'theme_neon', title: 'Neon Theme', cost: 50, requiredLevel: 3),
    Reward(id: 'avatar_shadow_ninja', title: 'Shadow Ninja', cost: 20, requiredLevel: 4),
    Reward(id: 'avatar_red_knight', title: 'Red Knight', cost: 20, requiredLevel: 5), 
    Reward(id: 'theme_retro', title: 'Retro Gaming Theme', cost: 50, requiredLevel: 6),
  ];

  // Firestore serialization for custom rewards
  factory Reward.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reward(
      id: doc.id,
      title: data['title'] ?? 'Unknown Reward',
      cost: data['cost'] ?? 0,
      requiredLevel: 0, 
      // User-created treats are explicitly marked as false so they can be bought repeatedly
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