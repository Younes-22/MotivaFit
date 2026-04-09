import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// A gamified achievements screen that displays a grid of all available badges. 
// It automatically checks the user's profile to determine which badges to light up and which ones to keep locked and hidden.
class TrophyRoomScreen extends StatelessWidget {
  const TrophyRoomScreen({super.key});

  // A quick mapping function that returns a specific color based on how hard the badge is to earn (e.g., Legendary badges get a shiny amber color).
  Color _getRarityColor(BadgeRarity rarity) {
    switch (rarity) {
      case BadgeRarity.common:
        return Colors.blueGrey;
      case BadgeRarity.rare:
        return Colors.blueAccent;
      case BadgeRarity.legendary:
        return Colors.amber;
    }
  }

  // Pops open a dialog when a user taps on a badge. If they haven't earned it yet, we hide the real name and just show the description as a hint on how to unlock it!
  void _showBadgeDetails(BuildContext context, BadgeModel badge, bool isUnlocked) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(
                isUnlocked ? badge.icon : Icons.lock,
                size: 60,
                color: isUnlocked ? _getRarityColor(badge.rarity) : Colors.grey.shade400,
              ),
              const SizedBox(height: 10),
              Text(
                isUnlocked ? badge.name : 'Locked Badge',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  // The main layout. It grabs the user's data stream so if they earn a badge while on this screen, the grid will instantly update to show their new trophy.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trophy Room', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<UserModel>(
        stream: FirestoreService().getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Unable to load badges."));
          }

          final user = snapshot.data!;
          final earnedBadgeIds = user.earnedBadges;

          return Column(
            children: [
              
              // A summary header at the top so the user always knows their total progress.
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Column(
                  children: [
                    Text(
                      '${earnedBadgeIds.length} / ${BadgeModel.allBadges.length}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const Text('Badges Unlocked', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),

              // Builds a flexible, scrollable grid that perfectly fits 3 badges per row.
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, 
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.8, // Slightly stretches the cards vertically so the text fits nicely
                  ),
                  itemCount: BadgeModel.allBadges.length,
                  itemBuilder: (context, index) {
                    final badge = BadgeModel.allBadges[index];
                    final isUnlocked = earnedBadgeIds.contains(badge.id);

                    // We wrap each badge in a GestureDetector so they act like buttons.
                    return GestureDetector(
                      onTap: () => _showBadgeDetails(context, badge, isUnlocked),
                      child: Container(
                        // Dynamically sets the background and border color based on rarity and lock status.
                        decoration: BoxDecoration(
                          color: isUnlocked 
                              ? _getRarityColor(badge.rarity).withValues(alpha: 0.1) 
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isUnlocked 
                                ? _getRarityColor(badge.rarity).withValues(alpha: 0.5) 
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isUnlocked ? badge.icon : Icons.lock,
                              size: 40,
                              color: isUnlocked 
                                  ? _getRarityColor(badge.rarity) 
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                isUnlocked ? badge.name : '???',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked 
                                      ? Theme.of(context).textTheme.bodyLarge?.color 
                                      : Colors.grey.shade500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}