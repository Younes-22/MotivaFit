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

  // A quick shortcut to grab the current user's ID.
  String? get _uid => _auth.currentUser?.uid;

  // User profile & Gamification Methods

  // Called the very first time a user signs up.
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

  // A live pipe to the user's profile.
  Stream<UserModel> getUserStream() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).snapshots()
        .map((doc) => UserModel.fromSnapshot(doc));
  }

  Future<void> updateUsername(String newName) async {
    if (_uid == null || newName.trim().isEmpty) return;
    await _db.collection('users').doc(_uid).update({
      'username': newName.trim(),
    });
  }

  Future<void> equipAvatar(String avatarId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'selectedAvatarId': avatarId,
    });
  }

  Future<void> equipTheme(String themeId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'selectedThemeId': themeId,
    });
  }

  bool _applyRewards(Transaction transaction, DocumentReference userRef, UserModel user, int xp, int coins, {List<String>? updatedBadges}) {
    int newXP = user.currentXP + xp;
    int newCoins = user.currentCoins + coins;
    int newLevel = user.currentLevel;
    List<String> currentBadges = updatedBadges ?? List.from(user.earnedBadges);

    const int xpRequired = 500; // Flat 500 XP per level
    
    // Level Up Logic. Safee for massive XP drops
    while (newXP >= xpRequired) {
      newLevel++;
      newXP -= xpRequired; 
      
      if (newLevel >= 5 && !currentBadges.contains('level_5')) currentBadges.add('level_5');
      if (newLevel >= 50 && !currentBadges.contains('level_50')) currentBadges.add('level_50');
    }

    // Level Down Logic. Safe for massive XP penalties
    while (newXP < 0 && newLevel > 1) {
      newLevel--;
      newXP += xpRequired;
    }
    
    // Absolute floor so they never go negative at Level 1
    if (newXP < 0) newXP = 0; 

    transaction.update(userRef, {
      'currentXP': newXP,
      'currentCoins': newCoins,
      'currentLevel': newLevel,
      'earnedBadges': currentBadges,
    });

    return newLevel > user.currentLevel;
  }

  // Task Methods

  Stream<List<Task>> getTasksForDay(DateTime date) {
    if (_uid == null) return const Stream.empty();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _db.collection('users').doc(_uid).collection('tasks')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Task.fromSnapshot(doc)).toList());
  }

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
      id: '', title: title, category: category, difficulty: difficulty, priority: priority, scheduledDate: cleanDate,
    );
    await _db.collection('users').doc(_uid).collection('tasks').add(newTask.toMap());
  }

Future<bool> toggleTaskCompletion(Task task, bool newStatus) async {
    if (_uid == null) return false;

    final userRef = _db.collection('users').doc(_uid);
    final taskRef = userRef.collection('tasks').doc(task.id);
    String bossId = _getCurrentWeekBossId();
    final bossRef = userRef.collection('boss_battles').doc(bossId);

    // Strip the hours/minutes to safely compare calendar days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(task.scheduledDate.year, task.scheduledDate.month, task.scheduledDate.day);
    
    // If the task date is strictly before today, it's overdue
    final bool isOverdue = taskDate.isBefore(today);

    return await _db.runTransaction<bool>((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final bossSnapshot = await transaction.get(bossRef);

      if (!userSnapshot.exists) throw Exception("Data missing");

      final user = UserModel.fromSnapshot(userSnapshot);
      
      // If overdue, rewards are 0. Otherwise, apply normal +/- rewards based on if they are checking or unchecking.
      int totalXp = 0;
      int totalCoins = 0;
      
      if (!isOverdue) {
        totalXp = newStatus ? task.xpReward : -task.xpReward;
        totalCoins = newStatus ? task.coinReward : -task.coinReward;
      }
      
      List<String> currentBadges = List.from(user.earnedBadges);

      // Save the actual checkbox status so their UI updates
      transaction.update(taskRef, {'isCompleted': newStatus});

      // Boss Damage is also restricted to active, on-time tasks
      if (newStatus && bossSnapshot.exists && !isOverdue) {
        bool bossDied = _internalBossDamage(transaction, bossSnapshot, bossRef, task.xpReward);
        if (bossDied) {
          totalXp += 500;
          totalCoins += 100;
          if (!currentBadges.contains('boss_slayer_1')) currentBadges.add('boss_slayer_1');
        }
      }

      // Commit the changes. If it was overdue, it safely adds 0 XP and 0 Coins.
      return _applyRewards(transaction, userRef, user, totalXp, totalCoins, updatedBadges: currentBadges);
    });
  }

  // Shop & reward methods

  Stream<List<Reward>> getCustomRewards() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).collection('custom_rewards')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Reward.fromSnapshot(doc)).toList());
  }

  Future<void> addCustomReward(String title, int cost) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('custom_rewards').add({
      'title': title, 'cost': cost, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCustomReward(String rewardId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('custom_rewards').doc(rewardId).delete();
  }

  Future<String?> purchaseReward(Reward reward) async {
    if (_uid == null) return "User not logged in";

    final userRef = _db.collection('users').doc(_uid);
    try {
      await _db.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw Exception("User not found");

        final user = UserModel.fromSnapshot(userSnapshot);
        if (user.currentCoins < reward.cost) throw Exception("Not enough coins!");
        if (reward.isPreset && user.currentLevel < reward.requiredLevel) throw Exception("Level too low to unlock this!");
        if (reward.isPreset && user.unlockedRewardIds.contains(reward.id)) throw Exception("You already own this item!");

        int newCoins = user.currentCoins - reward.cost;
        List<String> newUnlockedIds = List.from(user.unlockedRewardIds);
        if (reward.isPreset) newUnlockedIds.add(reward.id);

        transaction.update(userRef, {
          'currentCoins': newCoins,
          'unlockedRewardIds': newUnlockedIds,
        });
      });
      return null; 
    } catch (e) {
      return e.toString().replaceAll("Exception: ", ""); 
    }
  }

  // Nurition & Preferences Methods

  Future<void> updateNutritionGoals({required int calories, required int protein, required int carbs, required int fat}) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({'calorieGoal': calories, 'proteinGoal': protein, 'carbsGoal': carbs, 'fatGoal': fat});
  }

  Future<void> updateDietaryPreferences({required List<String> restrictions, required String goal}) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({'dietaryRestrictions': restrictions, 'fitnessGoal': goal});
  }

  Future<bool> logFood({required int calories, required int protein, required int carbs, required int fat, required DateTime date}) async {
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
      
      int dynamicMealDmg = user.targetWorkoutsPerWeek > 0 ? (300 / 7).round() : (1000 / 7).round();
      int totalXp = 10;
      int totalCoins = 2;
      List<String> currentBadges = List.from(user.earnedBadges);
      
      if (!currentBadges.contains('first_meal')) currentBadges.add('first_meal');

      if (nutritionDoc.exists) {
        transaction.update(nutritionRef, {
          'calories': FieldValue.increment(calories),
          'protein': FieldValue.increment(protein),
          'carbs': FieldValue.increment(carbs),
          'fat': FieldValue.increment(fat),
        });
      } else {
        transaction.set(nutritionRef, {
          'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat, 'date': Timestamp.fromDate(date),
        });
      }

      // Combine Boss XP with Meal XP before updating the user
      if (bossSnapshot.exists) {
        bool bossDied = _internalBossDamage(transaction, bossSnapshot, bossRef, dynamicMealDmg);
        if (bossDied) {
          totalXp += 500;
          totalCoins += 100;
          if (!currentBadges.contains('boss_slayer_1')) currentBadges.add('boss_slayer_1');
        }
      }

      return _applyRewards(transaction, userRef, user, totalXp, totalCoins, updatedBadges: currentBadges);
    });
  }

  Stream<NutritionDay> getNutritionForDate(DateTime date) {
    if (_uid == null) return const Stream.empty();
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _db.collection('users').doc(_uid).collection('nutrition').doc(dateId)
        .snapshots().map((doc) => !doc.exists ? NutritionDay(id: dateId, calories: 0, protein: 0, carbs: 0, fat: 0, date: date) : NutritionDay.fromSnapshot(doc));
  }

  Stream<List<NutritionDay>> getWeeklyNutrition() {
    if (_uid == null) return const Stream.empty();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _db.collection('users').doc(_uid).collection('nutrition')
        .where('date', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('date', descending: false)
        .snapshots().map((snapshot) => snapshot.docs.map((doc) => NutritionDay.fromSnapshot(doc)).toList());
  }

  // Workout & routine methods

  Future<bool> logExercise({required String name, required int sets, required String reps, required double weight, required DateTime date}) async {
    if (_uid == null) return false;

    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final userRef = _db.collection('users').doc(_uid);
    final workoutRef = userRef.collection('workouts').doc(dateId);
    final newExercise = Exercise(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, sets: sets, reps: reps, weight: weight);

    return await _db.runTransaction<bool>((transaction) async {
      final workoutSnapshot = await transaction.get(workoutRef);
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) return false;
      final user = UserModel.fromSnapshot(userSnapshot);

      if (workoutSnapshot.exists) {
        transaction.update(workoutRef, {'exercises': FieldValue.arrayUnion([newExercise.toMap()])});
      } else {
        transaction.set(workoutRef, {'date': Timestamp.fromDate(date), 'exercises': [newExercise.toMap()], 'isCompleted': false});
      }

      return _applyRewards(transaction, userRef, user, 20, 5);
    });
  }

  Future<void> createRoutine(String name, List<Exercise> exercises) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('routines').add({'name': name, 'exercises': exercises.map((e) => e.toMap()).toList(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Stream<List<WorkoutRoutine>> getRoutines() {
    if (_uid == null) return const Stream.empty();
    return _db.collection('users').doc(_uid).collection('routines').orderBy('name')
        .snapshots().map((s) => s.docs.map((d) => WorkoutRoutine.fromSnapshot(d)).toList());
  }

  Future<void> loadRoutineIntoToday(WorkoutRoutine routine, DateTime date) async {
    if (_uid == null) return;
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final workoutRef = _db.collection('users').doc(_uid).collection('workouts').doc(dateId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(workoutRef); 
      final exercisesData = routine.exercises.map((e) => e.toMap()).toList();

      if (snapshot.exists) {
        transaction.update(workoutRef, {'exercises': FieldValue.arrayUnion(exercisesData)});
      } else {
        transaction.set(workoutRef, {'date': Timestamp.fromDate(date), 'exercises': exercisesData, 'isCompleted': false});
      }
    });
  }

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

      if (!workoutDoc.exists || !userSnapshot.exists || workoutDoc.get('isCompleted') == true) return false; 
      
      final user = UserModel.fromSnapshot(userSnapshot);
      int dynamicWorkoutDmg = user.targetWorkoutsPerWeek > 0 ? (700 / user.targetWorkoutsPerWeek).round() : 0;
      
      int totalXp = 100;
      int totalCoins = 20;
      List<String> currentBadges = List.from(user.earnedBadges);
      
      if (!currentBadges.contains('first_workout')) currentBadges.add('first_workout');

      transaction.update(workoutRef, {'isCompleted': true});

      // Combine Boss XP with Workout XP before updating the user
      if (bossSnapshot.exists && dynamicWorkoutDmg > 0) {
        bool bossDied = _internalBossDamage(transaction, bossSnapshot, bossRef, dynamicWorkoutDmg);
        if (bossDied) {
          totalXp += 500;
          totalCoins += 100;
          if (!currentBadges.contains('boss_slayer_1')) currentBadges.add('boss_slayer_1');
        }
      }

      return _applyRewards(transaction, userRef, user, totalXp, totalCoins, updatedBadges: currentBadges);
    });
  }

  Future<void> deleteExercise(DateTime date, Exercise exercise) async {
    if (_uid == null) return;
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    await _db.collection('users').doc(_uid).collection('workouts').doc(dateId).update({'exercises': FieldValue.arrayRemove([exercise.toMap()])});
  }

  Future<void> deleteRoutine(String routineId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('routines').doc(routineId).delete();
  }

  Stream<WorkoutDay> getWorkoutForDate(DateTime date) {
    if (_uid == null) return const Stream.empty();
    final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return _db.collection('users').doc(_uid).collection('workouts').doc(dateId)
        .snapshots().map((doc) => !doc.exists ? WorkoutDay(id: dateId, date: date, exercises: []) : WorkoutDay.fromSnapshot(doc));
  }

  // Daily roll over logic (pentalty)

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

    if (currentDay.isBefore(lastActiveDay) || currentDay.isAtSameMomentAs(lastActiveDay)) return null;

    final endOfLastActiveDay = DateTime(lastActiveDay.year, lastActiveDay.month, lastActiveDay.day, 23, 59, 59);
    final tasksSnapshot = await _db.collection('users').doc(_uid).collection('tasks')
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(lastActiveDay))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfLastActiveDay))
        .where('isCompleted', isEqualTo: false).get();

    int totalPenalty = 0;
    int missedCount = 0;

    for (var doc in tasksSnapshot.docs) {
      final task = Task.fromSnapshot(doc);
      switch (task.priority) {
        case TaskPriority.low: totalPenalty += 5; break;
        case TaskPriority.normal: totalPenalty += 15; break;
        case TaskPriority.high: totalPenalty += 30; break;
      }
      missedCount++;
    }

    await userRef.update({
      'lastActiveDate': FieldValue.serverTimestamp(),
      'currentCoins': (user.currentCoins - totalPenalty).clamp(0, 999999), 
    });

    if (missedCount > 0) return "While you were away, you missed $missedCount tasks and lost $totalPenalty coins.";
    return "Welcome back! You had a perfect streak last time.";
  }

  // Debug / Settings
  
  Future<void> resetAccount() async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'currentLevel': 1, 'currentXP': 0, 'currentCoins': 0, 'unlockedRewardIds': [], 'selectedAvatarId': 'default', 'earnedBadges': [], 
    });
  }

  // Boss Battle Methods

  String _getCurrentWeekBossId() {
    DateTime now = DateTime.now();
    DateTime monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return "boss_${monday.year}_${monday.month.toString().padLeft(2, '0')}_${monday.day.toString().padLeft(2, '0')}";
  }

  Stream<BossModel?> getCurrentBossStream() {
    if (_uid == null) return const Stream.empty();
    String bossId = _getCurrentWeekBossId();
    return _db.collection('users').doc(_uid).collection('boss_battles').doc(bossId)
      .snapshots().map((doc) => !doc.exists ? null : BossModel.fromSnapshot(doc));
  }

  Future<void> _ensureWeeklyBossExists() async {
    if (_uid == null) return;

    String bossId = _getCurrentWeekBossId();
    final bossRef = _db.collection('users').doc(_uid).collection('boss_battles').doc(bossId);
    final bossDoc = await bossRef.get();
    if (bossDoc.exists) return;

    DateTime now = DateTime.now();
    DateTime startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    List<String> bossNames = ["The Junk Food Golem", "The Couch Potato King", "The Lazy Phantom", "The Sugar Slime", "The Snooze Titan"];
    bossNames.shuffle();

    await bossRef.set({
      'name': bossNames.first, 'maxHp': 1000, 'currentHp': 1000, 'isDefeated': false,
      'startDate': Timestamp.fromDate(startOfWeek), 'endDate': Timestamp.fromDate(endOfWeek),
    });
  }

  bool _internalBossDamage(Transaction transaction, DocumentSnapshot bossSnap, DocumentReference bossRef, int damage) {
    final boss = BossModel.fromSnapshot(bossSnap);
    
    if (boss.isDefeated) return false;

    int newHp = (boss.currentHp - damage).clamp(0, boss.maxHp);
    bool isNowDefeated = newHp == 0;

    transaction.update(bossRef, {
      'currentHp': newHp,
      'isDefeated': isNowDefeated,
    });

    return isNowDefeated;
  }
}