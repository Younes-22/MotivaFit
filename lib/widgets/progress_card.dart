import 'package:flutter/material.dart';

// A visual scoreboard that sits at the top of the home screen.
// It displays the user's current level, progress to the next level and their total coin balance.
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

    // Avatar Visual Logic
    // Maps the string ID saved in the database to a specific Flutter icon and color.
    IconData avatarIcon;
    Color avatarColor;

    switch (selectedAvatarId) {
      case 'avatar_green_novice': 
        avatarIcon = Icons.face;
        avatarColor = Colors.greenAccent; 
        break;
      case 'avatar_blue_warrior':
        avatarIcon = Icons.shield;
        avatarColor = Colors.blue; 
        break;
      case 'avatar_crimson_firebender': 
        avatarIcon = Icons.local_fire_department;
        avatarColor = Colors.orange;
        break;
      case 'avatar_shadow_ninja':
        avatarIcon = Icons.sports_martial_arts;
        avatarColor = Colors.deepPurpleAccent; 
        break;
      case 'avatar_red_knight':
        avatarIcon = Icons.security;
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
                
                // Left Side: Avatar and Level Info
                // Wrapped in Expanded to prevent the 0.114 pixel overflow on smaller phones
                Expanded(
                  child: Row(
                    children: [
                      // Avatar Circle
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.black26, 
                        child: Icon(avatarIcon, color: avatarColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      
                      // Level Info
                      // Wrapped in Expanded so long level text shrinks instead of pushing the coins off screen
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL $level',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$currentXP / 500 XP',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8), // A small buffer between the text and the coins

                // Right Side: Coin Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
            
            // The XP Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: Colors.black.withValues(alpha: 0.1),
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}