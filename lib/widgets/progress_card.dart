import 'package:flutter/material.dart';

class ProgressCard extends StatelessWidget {
  final int level;
  final int currentXP;
  final int currentCoins;
  final double progress;
  final String selectedAvatarId;

  const ProgressCard({
    super.key,
    required this.level,
    required this.currentXP,
    required this.currentCoins,
    required this.progress,
    this.selectedAvatarId = 'default',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- Avatar Visual Logic ---
    IconData avatarIcon;
    Color avatarColor;

    switch (selectedAvatarId) {
      case 'avatar_novice': 
        avatarIcon = Icons.face; // Restored your original design
        avatarColor = Colors.greenAccent; 
        break;
      case 'avatar_blue':
        avatarIcon = Icons.shield; // Restored your original design
        avatarColor = Colors.blue; 
        break;
      case 'avatar_fire': // 🔥 NEW: The Crimson Firebender
        avatarIcon = Icons.local_fire_department;
        avatarColor = Colors.orange;
        break;
      case 'avatar_shadow_ninja':
        avatarIcon = Icons.sports_martial_arts; // Restored your original design
        avatarColor = Colors.deepPurpleAccent; 
        break;
      case 'avatar_red_knight':
        avatarIcon = Icons.security; // Restored your original design
        avatarColor = Colors.redAccent; 
        break;
      case 'default':
      default:
        avatarIcon = Icons.person;
        avatarColor = Colors.white;
        break;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Side: Avatar + Level Info
                Row(
                  children: [
                    // --- Avatar Circle ---
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black26, // Restored your original background
                      child: Icon(avatarIcon, color: avatarColor, size: 28),
                    ),
                    const SizedBox(width: 12),
                    
                    // --- Level Info ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEVEL $level',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimary.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentXP / 500 XP',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Right Side: Coin Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$currentCoins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.black.withOpacity(0.1),
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}