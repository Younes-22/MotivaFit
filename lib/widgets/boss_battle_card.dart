import 'package:flutter/material.dart';
import '../models/boss_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class BossBattleCard extends StatelessWidget {
  final UserModel user; 

  const BossBattleCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BossModel?>(
      stream: FirestoreService().getCurrentBossStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final boss = snapshot.data;

        if (boss == null) {
          return const SizedBox.shrink();
        }

        double healthPercent = boss.currentHp / boss.maxHp;
        
        int daysLeft = boss.endDate.difference(DateTime.now()).inDays;
        if (daysLeft < 0) daysLeft = 0;

        // CALCULATE DYNAMIC HINT TEXT
        int workoutDmg = user.targetWorkoutsPerWeek > 0 ? (700 / user.targetWorkoutsPerWeek).round() : 0;
        int mealDmg = user.targetWorkoutsPerWeek > 0 ? (300 / 7).round() : (1000 / 7).round();
        
        // UPDATED: Short, concise, and includes Task XP math
        String hintText = user.targetWorkoutsPerWeek > 0 
            ? "Deal $workoutDmg DMG/Workout, $mealDmg DMG/Meal & Task DMG = XP!"
            : "Recovery: $mealDmg DMG/Meal & Task DMG = XP!";

        // VICTORY STATE
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

        // ACTIVE BOSS STATE
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
                        color: Colors.white.withOpacity(0.2),
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
                
                // --- DYNAMIC HINT TEXT USED HERE ---
                Center(
                  child: Text(
                    hintText,
                    style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center, // Added alignment for safety
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