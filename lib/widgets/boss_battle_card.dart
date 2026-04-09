import 'package:flutter/material.dart';
import '../models/boss_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

// A dynamic UI widget that sits on the Home Screen. It acts as a live scoreboard for the weekly Boss Battle, updating in real-time as the user logs tasks and deals damage.
class BossBattleCard extends StatelessWidget {
  final UserModel user; 

  const BossBattleCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // We wrap the entire card in a StreamBuilder. If the user logs a meal, the database updates, and this card instantly repaints to show the boss's health dropping.
    return StreamBuilder<BossModel?>(
      stream: FirestoreService().getCurrentBossStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final boss = snapshot.data;

        // If it's Sunday night and the old boss is gone but the new one hasn't spawned yet, we just shrink the card so it disappears completely.
        if (boss == null) {
          return const SizedBox.shrink();
        }

        double healthPercent = boss.currentHp / boss.maxHp;
        
        int daysLeft = boss.endDate.difference(DateTime.now()).inDays;
        if (daysLeft < 0) daysLeft = 0;
        
        // Calculate dynamic hint text
        // We look at the user's specific weekly goals to tell them exactly how much damage their specific actions will do. This ensures a sedentary user playing for recovery can still defeat the boss purely through nutrition and tasks.
        int workoutDmg = user.targetWorkoutsPerWeek > 0 ? (700 / user.targetWorkoutsPerWeek).round() : 0;
        int mealDmg = user.targetWorkoutsPerWeek > 0 ? (300 / 7).round() : (1000 / 7).round();
        
        String hintText = user.targetWorkoutsPerWeek > 0 
            ? "Deal $workoutDmg DMG/Workout, $mealDmg DMG/Meal & Task DMG = XP!"
            : "Recovery: $mealDmg DMG/Meal & Task DMG = XP!";

        // Victory state
        // Once the boss hits 0 HP, we swap out the intimidating red gradient for a celebratory gold card until Monday rolls around.
        if (boss.isDefeated) {
          return Card(
            elevation: 4,
            color: Colors.amber.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Boss Defeated!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const Text(
                          "Great job! A new boss will appear next Monday.",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Active boss state
        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade900, Colors.black87],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // The Boss Name & Countdown Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        boss.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2), // Updated to modern syntax!
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "$daysLeft days left",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // The Boss Avatar & Raw HP Numbers
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: const Icon(Icons.pest_control, color: Colors.redAccent, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BOSS HP",
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${boss.currentHp} / ${boss.maxHp}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),

                // The Health Bar. It dynamically changes color from Green to Orange to Red as the boss's health gets low.
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: healthPercent,
                    minHeight: 12,
                    backgroundColor: Colors.white24,
                    color: healthPercent > 0.5 
                        ? Colors.greenAccent 
                        : (healthPercent > 0.2 ? Colors.orangeAccent : Colors.redAccent),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // The strategy guide letting the user know exactly how to deal damage
                Center(
                  child: Text(
                    hintText,
                    style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center, 
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}