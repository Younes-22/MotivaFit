import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/reward_model.dart';
import '../models/nutrition_model.dart';
import '../models/workout_model.dart'; 
import '../models/boss_model.dart';

// The master database controller. Every time the app needs to save a workout, fetch a task, or update the user's XP, it passes through this service.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // A quick shortcut to grab the current user's ID. We use this in almost every method to make sure users can only read/write their own private data.
  String? get _uid => _auth.currentUser?.uid;

  // User Pofile & Gamification Methods

  // Called the very first time a user signs up. It creates their blank slate in the database with Level 1 stats, zero coins, and default nutrition targets.
  Future<void> createUserProfile(User user, String username) async {
    final docRef = _db.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) {
      await docRef.set({
        'email': user.email,
        'username': username,
        'currentLevel': 1,
        'currentXP': 0,
        'currentCoins': 0,
        'unlockedRewardIds': [], 
        'selectedAvatarId': 'default', 
        'selectedThemeId': 'default',
        'earnedBadges': [], 
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveDate': FieldValue.serverTimestamp(),
        'calorieGoal': 2000,
        'proteinGoal': 150,
        'carbsGoal': 200,
        'fatGoal': 70,
        'targetWorkoutsPerWeek': 3, 
        'dietaryRestrictions': [],
        'fitnessGoal': 'Maintain',
      });
    }
  }

  // A live pipe to the user's profile. Any time their XP, Coins, or Settings change in the database, this stream instantly updates the UI across the whole app.
  Stream<UserModel> getUserStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).snapshots()
        .map((doc) => UserModel.fromSnapshot(doc));
  }

  // Lets the user change their display name at any time from the Home Screen.
  Future<void> updateUsername(String newName) async {
    if (_uid == null || newName.trim().isEmpty) return;
    await _db.collection('users').doc(_uid).update({
      'username': newName.trim(),
    });
  }

  // Swaps out the user's active avatar icon.
  Future<void> equipAvatar(String avatarId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'selectedAvatarId': avatarId,
    });
  }

  // Swaps out the app's visual color scheme.
  Future<void> equipTheme(String themeId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'selectedThemeId': themeId,
    });
  }

  // Internal Helper: Award XP & Coins
  // The master math function for gamification. It handles adding XP, checking if the user crossed the 500 XP threshold to level up, and silently assigning milestone badges.
  // It is injected into Transactions to ensure database safety.
  bool _applyRewards(Transaction transaction, DocumentReference userRef, UserModel user, int xp, int coins, {List<String>? updatedBadges}) {
    int newXP = user.currentXP + xp;
    int newCoins = user.currentCoins + coins;
    int newLevel = user.currentLevel;
    List<String> currentBadges = updatedBadges ?? List.from(user.earnedBadges);

    int xpRequired = newLevel * 500;
    
    // Level Up Logic
    if (newXP >= xpRequired) {
      newLevel++;
      newXP -= xpRequired; 
      
      if (newLevel >= 5 && !currentBadges.contains('level_5')) {
        currentBadges.add('level_5');
      }
      if (newLevel >= 50 && !currentBadges.contains('level_50')) {
        currentBadges.add('level_50');
      }
    // Level Down Logic (If they lost XP from unchecking a task)
    } else if (newXP < 0 && newLevel > 1) {
      newLevel--;
      newXP += (newLevel * 500);
    }

    transaction.update(userRef, {
      'currentXP': newXP,
      'currentCoins': newCoins,
      'currentLevel': newLevel,
      'earnedBadges': currentBadges,
    });

    // Returns true if they actually leveled up so the UI can show a celebration pop-up
    return newLevel > user.currentLevel;
  }

  // Task Methods

  // Grabs all the tasks scheduled for a very specific 24-hour window to populate the daily calendar.
  Stream<List<Task>> getTasksForDay(DateTime date) {
    if (_uid == null) return const Stream.empty();

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _db
        .collection('users')
        .doc(_uid)
        .collection('tasks')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Task.fromSnapshot(doc)).toList());
  }

  // Creates a brand new to-do item and drops it into the database for the selected day.
  Future<void> addTask({
    required String title,
    required String category,
    required TaskDifficulty difficulty,
    required TaskPriority priority,
    required DateTime date,
  }) async {
    if (_uid == null) return;
    
    final cleanDate = DateTime(date.year, date.month, date.day);

    final newTask = Task(
      id: '', 
      title: title,
      category: category,
      difficulty: difficulty,
      priority: priority,
      scheduledDate: cleanDate,
    );

    await _db.collection('users').doc(_uid).collection('tasks').add(newTask.toMap());
  }

  // Checks or unchecks a task. It uses a Transaction so if the user checks off a task, earns XP, levels up, and damages the boss, all of those database updates happen simultaneously.
  Future<bool> toggleTaskCompletion(Task task, bool newStatus) async {
    if (_uid == null) return false;

    final userRef = _db.collection('users').doc(_uid);
    final taskRef = userRef.collection('tasks').doc(task.id);
    
    String bossId = _getCurrentWeekBossId();
    final bossRef = userRef.collection('boss_battles').doc(bossId);

    return await _db.runTransaction<bool>((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final taskSnapshot = await transaction.get(taskRef);
      final bossSnapshot = await transaction.get(bossRef);

      if (!userSnapshot.exists || !taskSnapshot.exists) {
        throw Exception("Data missing");
      }

      final user = UserModel.fromSnapshot(userSnapshot);
      
      // If checking the box, give positive XP. If unchecking, give negative XP to take it back.
      int xpDelta = newStatus ? task.xpReward : -task.xpReward;
      int coinDelta = newStatus ? task.coinReward : -task.coinReward;

      // Update the actual task status
      transaction.update(taskRef, {'isCompleted': newStatus});

      // Rely on our master helper function to handle all the complicated math!
      bool didLevelUp = _applyRewards(transaction, userRef, user, xpDelta, coinDelta);

      // If they finished a task and the boss is alive, deal exactly 10 damage
      if (newStatus && bossSnapshot.exists) {
        _internalBossDamage(transaction, bossSnapshot, bossRef, userRef, user, 10);
      }

      return didLevelUp;
    });
  }

  // Shop & Reward Methods

  // Fetches the user's custom, real-life treats (like "1 Hour of TV") to display in the shop.
  Stream<List<Reward>> getCustomRewards() {
    if (_uid == null) return const Stream.empty();
    
    return _db
        .collection('users')
        .doc(_uid)
        .collection('custom_rewards')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => Reward.fromSnapshot(doc)).toList());
  }

  // Allows the user to invent a new custom reward and price it however they want.
  Future<void> addCustomReward(String title, int cost) async {
    if (_uid == null) return;
    
    await _db.collection('users').doc(_uid).collection('custom_rewards').add({
      'title': title,
      'cost': cost,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Trashes a custom reward if the user doesn't want it clogging up their shop anymore.
  Future<void> deleteCustomReward(String rewardId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('custom_rewards').doc(rewardId).delete();
  }

  // The checkout counter. It ensures the user has enough coins and a high enough level before unlocking the item and subtracting the funds.
  Future<String?> purchaseReward(Reward reward) async {
    if (_uid == null) return "User not logged in";

    final userRef = _db.collection('users').doc(_uid);

    try {
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("User not found");

        final user = UserModel.fromSnapshot(userSnapshot);

        if (user.currentCoins < reward.cost) {
          throw Exception("Not enough coins!");
        }

        if (reward.isPreset && user.currentLevel < reward.requiredLevel) {
          throw Exception("Level too low to unlock this!");
        }

        if (reward.isPreset && user.unlockedRewardIds.contains(reward.id)) {
          throw Exception("You already own this item!");
        }

        int newCoins = user.currentCoins - reward.cost;
        
        List<String> newUnlockedIds = List.from(user.unlockedRewardIds);
        if (reward.isPreset) {
          newUnlockedIds.add(reward.id);
        }

        transaction.update(userRef, {
          'currentCoins': newCoins,
          'unlockedRewardIds': newUnlockedIds,
        });
      });
      return null; // Return null if the purchase was successful
    } catch (e) {
      return e.toString().replaceAll("Exception: ", ""); // Return the error message to show in the UI
    }
  }

  // Nutrition & preferences methods

  // Saves the user's specific calorie and macro goals (usually generated during Onboarding or Settings).
  Future<void> updateNutritionGoals({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'calorieGoal': calories,
      'proteinGoal': protein,
      'carbsGoal': carbs,
      'fatGoal': fat,
    });
  }

  // Saves the user's dietary allergies/rules and whether they want to lose, maintain, or build mass.
  Future<void> updateDietaryPreferences({
    required List<String> restrictions,
    required String goal,
  }) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'dietaryRestrictions': restrictions,
      'fitnessGoal': goal,
    });
  }

  // Adds food to today's tally. If it's the very first time they log a meal, it awards a badge. It also automatically calculates boss damage.
  Future<bool> logFood({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required DateTime date,
  }) async {
    if (_uid == null) return false;

    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final userRef = _db.collection('users').doc(_uid);
    final nutritionRef = userRef.collection('nutrition').doc(dateId);
    
    String bossId = _getCurrentWeekBossId();
    final bossRef = userRef.collection('boss_battles').doc(bossId);

    return await _db.runTransaction<bool>((transaction) async {
      final nutritionDoc = await transaction.get(nutritionRef);
      final userSnapshot = await transaction.get(userRef);
      final bossSnapshot = await transaction.get(bossRef);

      if (!userSnapshot.exists) return false;
      
      final user = UserModel.fromSnapshot(userSnapshot);
      
      // Damage calculation based on how often they workout (so sedentary users can still win via nutrition)
      int dynamicMealDmg = user.targetWorkoutsPerWeek > 0 
          ? (300 / 7).round() 
          : (1000 / 7).round();

      List<String> currentBadges = List.from(user.earnedBadges);
      if (!currentBadges.contains('first_meal')) {
        currentBadges.add('first_meal');
      }

      if (nutritionDoc.exists) {
        transaction.update(nutritionRef, {
          'calories': FieldValue.increment(calories),
          'protein': FieldValue.increment(protein),
          'carbs': FieldValue.increment(carbs),
          'fat': FieldValue.increment(fat),
        });
      } else {
        transaction.set(nutritionRef, {
          'calories': calories,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'date': Timestamp.fromDate(date),
        });
      }

      if (bossSnapshot.exists) {
        _internalBossDamage(transaction, bossSnapshot, bossRef, userRef, user, dynamicMealDmg);
      }

      return _applyRewards(transaction, userRef, user, 10, 2, updatedBadges: currentBadges);
    });
  }

  // Grabs the specific macro totals for one specific day to display on the Nutrition Dashboard.
  Stream<NutritionDay> getNutritionForDate(DateTime date) {
    if (_uid == null) return const Stream.empty();
    
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    return _db.collection('users').doc(_uid).collection('nutrition').doc(dateId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return NutritionDay(id: dateId, calories: 0, protein: 0, carbs: 0, fat: 0, date: date);
          }
          return NutritionDay.fromSnapshot(doc);
        });
  }

  // Grabs the last 7 days of eating history to build the Weekly Bar Chart.
  Stream<List<NutritionDay>> getWeeklyNutrition() {
    if (_uid == null) return const Stream.empty();

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    return _db.collection('users').doc(_uid).collection('nutrition')
        .where('date', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => NutritionDay.fromSnapshot(doc)).toList());
  }

  // Workout & Routine Methods

  // Adds a single exercise (like 3 sets of Bench Press) to the active day's log.
  Future<bool> logExercise({
    required String name,
    required int sets,
    required String reps,
    required double weight,
    required DateTime date,
  }) async {
    if (_uid == null) return false;

    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final userRef = _db.collection('users').doc(_uid);
    final workoutRef = userRef.collection('workouts').doc(dateId);

    final newExercise = Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sets: sets,
      reps: reps,
      weight: weight,
    );

    return await _db.runTransaction<bool>((transaction) async {
      final workoutSnapshot = await transaction.get(workoutRef);
      final userSnapshot = await transaction.get(userRef);
      
      if (!userSnapshot.exists) return false;
      final user = UserModel.fromSnapshot(userSnapshot);

      if (workoutSnapshot.exists) {
        transaction.update(workoutRef, {
          'exercises': FieldValue.arrayUnion([newExercise.toMap()]),
        });
      } else {
        transaction.set(workoutRef, {
          'date': Timestamp.fromDate(date),
          'exercises': [newExercise.toMap()],
          'isCompleted': false,
        });
      }

      return _applyRewards(transaction, userRef, user, 20, 5);
    });
  }

  // Bundles a list of exercises into a reusable template for the user's "My Plans" tab.
  Future<void> createRoutine(String name, List<Exercise> exercises) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('routines').add({
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Fetches all the user's saved workout templates.
  Stream<List<WorkoutRoutine>> getRoutines() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).collection('routines')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => WorkoutRoutine.fromSnapshot(d)).toList());
  }

  // Copies all the exercises from a saved Template and drops them directly into Today's Log.
  Future<void> loadRoutineIntoToday(WorkoutRoutine routine, DateTime date) async {
    if (_uid == null) return;
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final workoutRef = _db.collection('users').doc(_uid).collection('workouts').doc(dateId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(workoutRef); 
      final exercisesData = routine.exercises.map((e) => e.toMap()).toList();

      if (snapshot.exists) {
        transaction.update(workoutRef, {
          'exercises': FieldValue.arrayUnion(exercisesData),
        });
      } else {
        transaction.set(workoutRef, {
          'date': Timestamp.fromDate(date),
          'exercises': exercisesData,
          'isCompleted': false,
        });
      }
    });
  }

  // Locks in the workout, prevents further editing, awards massive XP, and strikes the boss!
  Future<bool> finishWorkout(DateTime date) async {
    if (_uid == null) return false;
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final userRef = _db.collection('users').doc(_uid);
    final workoutRef = userRef.collection('workouts').doc(dateId);
    
    String bossId = _getCurrentWeekBossId();
    final bossRef = userRef.collection('boss_battles').doc(bossId);

    return await _db.runTransaction<bool>((transaction) async {
      final workoutDoc = await transaction.get(workoutRef);
      final userSnapshot = await transaction.get(userRef);
      final bossSnapshot = await transaction.get(bossRef);

      if (!workoutDoc.exists || !userSnapshot.exists) return false; 
      if (workoutDoc.get('isCompleted') == true) return false; 
      
      final user = UserModel.fromSnapshot(userSnapshot);
      
      int dynamicWorkoutDmg = user.targetWorkoutsPerWeek > 0 
          ? (700 / user.targetWorkoutsPerWeek).round() 
          : 0;

      List<String> currentBadges = List.from(user.earnedBadges);
      if (!currentBadges.contains('first_workout')) {
        currentBadges.add('first_workout');
      }

      transaction.update(workoutRef, {'isCompleted': true});

      if (bossSnapshot.exists && dynamicWorkoutDmg > 0) {
        _internalBossDamage(transaction, bossSnapshot, bossRef, userRef, user, dynamicWorkoutDmg);
      }

      return _applyRewards(transaction, userRef, user, 100, 20, updatedBadges: currentBadges);
    });
  }

  // Removes a single exercise from today's active log.
  Future<void> deleteExercise(DateTime date, Exercise exercise) async {
    if (_uid == null) return;
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    await _db.collection('users').doc(_uid).collection('workouts').doc(dateId).update({
      'exercises': FieldValue.arrayRemove([exercise.toMap()])
    });
  }

  // Completely deletes a saved template from the user's "My Plans" tab.
  Future<void> deleteRoutine(String routineId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('routines').doc(routineId).delete();
  }

  // Grabs whatever is currently active in the user's workout log for today.
  Stream<WorkoutDay> getWorkoutForDate(DateTime date) {
    if (_uid == null) return const Stream.empty();
    
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    return _db.collection('users').doc(_uid).collection('workouts').doc(dateId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            return WorkoutDay(id: dateId, date: date, exercises: []);
          }
          return WorkoutDay.fromSnapshot(doc);
        });
  }

  // Daily Rollover Logic (Penalties)

  // Runs silently in the background when the Home Screen opens. If the user hasn't opened the app since yesterday, it hunts down any tasks they forgot to check off and subtracts coins from their account as a penalty.
  Future<String?> checkDailyRollover() async {
    if (_uid == null) return null;

    await _ensureWeeklyBossExists();

    final userRef = _db.collection('users').doc(_uid);
    final userSnapshot = await userRef.get();
    
    if (!userSnapshot.exists) return null;
    
    final user = UserModel.fromSnapshot(userSnapshot);
    final now = DateTime.now();
    
    final lastActive = (userSnapshot.data() as Map<String, dynamic>)['lastActiveDate'] != null 
        ? (userSnapshot.data() as Map<String, dynamic>)['lastActiveDate'].toDate() 
        : now;

    final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
    final currentDay = DateTime(now.year, now.month, now.day);

    if (currentDay.isBefore(lastActiveDay) || currentDay.isAtSameMomentAs(lastActiveDay)) {
      return null;
    }

    final endOfLastActiveDay = DateTime(lastActiveDay.year, lastActiveDay.month, lastActiveDay.day, 23, 59, 59);

    final tasksSnapshot = await _db.collection('users').doc(_uid).collection('tasks')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(lastActiveDay))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfLastActiveDay))
        .where('isCompleted', isEqualTo: false) 
        .get();

    int totalPenalty = 0;
    int missedCount = 0;

    for (var doc in tasksSnapshot.docs) {
      final task = Task.fromSnapshot(doc);
      int penalty = 0;
      switch (task.priority) {
        case TaskPriority.low: penalty = 5; break;
        case TaskPriority.normal: penalty = 15; break;
        case TaskPriority.high: penalty = 30; break;
      }
      totalPenalty += penalty;
      missedCount++;
    }

    await userRef.update({
      'lastActiveDate': FieldValue.serverTimestamp(),
      'currentCoins': (user.currentCoins - totalPenalty).clamp(0, 999999), 
    });

    if (missedCount > 0) {
      return "While you were away, you missed $missedCount tasks and lost $totalPenalty coins.";
    } else {
      return "Welcome back! You had a perfect streak last time.";
    }
  }

  // Debug / Settings
  
  // A hidden developer tool used to test onboarding and progression features from scratch.
  Future<void> resetAccount() async {
    if (_uid == null) return;
    
    await _db.collection('users').doc(_uid).update({
      'currentLevel': 1,
      'currentXP': 0,
      'currentCoins': 0,
      'unlockedRewardIds': [],
      'selectedAvatarId': 'default',
      'earnedBadges': [], 
    });
  }

  // BOSS BATTLE METHODS

  // Helper method to ensure everyone in the app is fighting the exact same boss this week.
  String _getCurrentWeekBossId() {
    DateTime now = DateTime.now();
    DateTime monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return "boss_${monday.year}_${monday.month.toString().padLeft(2, '0')}_${monday.day.toString().padLeft(2, '0')}";
  }

  // A live pipe that constantly updates the Boss Card on the Home Screen as the community deals damage.
  Stream<BossModel?> getCurrentBossStream() {
    if (_uid == null) return const Stream.empty();
    
    String bossId = _getCurrentWeekBossId();
    
    return _db.collection('users').doc(_uid).collection('boss_battles').doc(bossId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        return BossModel.fromSnapshot(doc);
      });
  }

  // Runs quietly in the background on Monday mornings. If no boss exists for the week yet, it randomly generates a new one with 1000 HP.
  Future<void> _ensureWeeklyBossExists() async {
    if (_uid == null) return;

    String bossId = _getCurrentWeekBossId();
    final bossRef = _db.collection('users').doc(_uid).collection('boss_battles').doc(bossId);
    
    final bossDoc = await bossRef.get();
    
    if (bossDoc.exists) return;

    DateTime now = DateTime.now();
    DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    List<String> bossNames = [
      "The Junk Food Golem",
      "The Couch Potato King",
      "The Procrastination Phantom",
      "The Sugar Slime",
      "The Snooze Button Behemoth"
    ];
    bossNames.shuffle();

    await bossRef.set({
      'name': bossNames.first,
      'maxHp': 1000,
      'currentHp': 1000,
      'isDefeated': false,
      'startDate': Timestamp.fromDate(startOfWeek),
      'endDate': Timestamp.fromDate(endOfWeek),
    });
  }

  // The combat logic. Subtracts health from the boss and checks if this specific hit was the fatal blow. If so, it awards the user a massive XP bounty and a slayer badge!
  void _internalBossDamage(Transaction transaction, DocumentSnapshot bossSnap, DocumentReference bossRef, DocumentReference userRef, UserModel user, int damage) {
    final boss = BossModel.fromSnapshot(bossSnap);
    
    if (boss.isDefeated) return;

    int newHp = (boss.currentHp - damage).clamp(0, boss.maxHp);
    bool isNowDefeated = newHp == 0;

    transaction.update(bossRef, {
      'currentHp': newHp,
      'isDefeated': isNowDefeated,
    });

    if (isNowDefeated) {
      List<String> badges = List.from(user.earnedBadges);
      if (!badges.contains('boss_slayer_1')) {
        badges.add('boss_slayer_1');
      }

      _applyRewards(transaction, userRef, user, 500, 100, updatedBadges: badges);
    }
  }
}