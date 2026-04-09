import 'package:flutter/material.dart';

enum BadgeRarity { common, rare, legendary }

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final BadgeRarity rarity;
  final IconData icon;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
    required this.icon,
  });

  // A list of all badges available in the game
  static const List<BadgeModel> allBadges = [
    // Common
    BadgeModel(
      id: 'first_workout',
      name: 'First Steps',
      description: 'Log your very first workout.',
      rarity: BadgeRarity.common,
      icon: Icons.directions_run,
    ),
    BadgeModel(
      id: 'first_meal',
      name: 'Nutritionist',
      description: 'Log your first meal.',
      rarity: BadgeRarity.common,
      icon: Icons.restaurant,
    ),
    
    // Rare
    BadgeModel(
      id: 'level_5',
      name: 'Rising Star',
      description: 'Reach Level 5.',
      rarity: BadgeRarity.rare,
      icon: Icons.star,
    ),
    BadgeModel(
      id: 'boss_slayer_1',
      name: 'Giant Slayer',
      description: 'Defeat your first Weekly Boss.',
      rarity: BadgeRarity.rare,
      icon: Icons.shield,
    ),

    // Legendary
    BadgeModel(
      id: 'level_50',
      name: 'Titan of Fitness',
      description: 'Reach Level 50.',
      rarity: BadgeRarity.legendary,
      icon: Icons.workspace_premium,
    ),
  ];
}