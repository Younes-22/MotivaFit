import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final int currentLevel;
  final int currentXP;
  final int currentCoins;
  final List<String> unlockedRewardIds;
  final String selectedAvatarId;
  final String selectedThemeId; // <--- 1. NEW PROPERTY
  final List<String> earnedBadges; 
  
  final int calorieGoal;
  final int proteinGoal; 
  final int carbsGoal;   
  final int fatGoal;     
  final int targetWorkoutsPerWeek;

  // --- NEW FIELDS ---
  final List<String> dietaryRestrictions; // e.g. ['Halal', 'Vegan', 'No Nuts']
  final String fitnessGoal; // e.g. 'Lose Weight', 'Build Muscle', 'Maintain'

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.currentLevel = 1,
    this.currentXP = 0,
    this.currentCoins = 0,
    this.unlockedRewardIds = const [],
    this.selectedAvatarId = 'default',
    this.selectedThemeId = 'default', // <--- 2. NEW DEFAULT VALUE
    this.earnedBadges = const [], 
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.carbsGoal = 200,
    this.fatGoal = 70,
    this.targetWorkoutsPerWeek = 3,
    this.dietaryRestrictions = const [], 
    this.fitnessGoal = 'Maintain', 
  });

  factory UserModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? 'User',
      currentLevel: data['currentLevel'] ?? 1,
      currentXP: data['currentXP'] ?? 0,
      currentCoins: data['currentCoins'] ?? 0,
      unlockedRewardIds: List<String>.from(data['unlockedRewardIds'] ?? []),
      selectedAvatarId: data['selectedAvatarId'] ?? 'default',
      selectedThemeId: data['selectedThemeId'] ?? 'default', // <--- 3. READ FROM FIRESTORE
      earnedBadges: List<String>.from(data['earnedBadges'] ?? []), 
      calorieGoal: data['calorieGoal'] ?? 2000,
      proteinGoal: data['proteinGoal'] ?? 150,
      carbsGoal: data['carbsGoal'] ?? 200,
      fatGoal: data['fatGoal'] ?? 70,
      targetWorkoutsPerWeek: data['targetWorkoutsPerWeek'] ?? 3,
      dietaryRestrictions: List<String>.from(data['dietaryRestrictions'] ?? []),
      fitnessGoal: data['fitnessGoal'] ?? 'Maintain',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'currentLevel': currentLevel,
      'currentXP': currentXP,
      'currentCoins': currentCoins,
      'unlockedRewardIds': unlockedRewardIds,
      'selectedAvatarId': selectedAvatarId,
      'selectedThemeId': selectedThemeId, // <--- 4. WRITE TO FIRESTORE
      'earnedBadges': earnedBadges, 
      'lastActiveDate': FieldValue.serverTimestamp(),
      'calorieGoal': calorieGoal,
      'proteinGoal': proteinGoal,
      'carbsGoal': carbsGoal,
      'fatGoal': fatGoal,
      'targetWorkoutsPerWeek': targetWorkoutsPerWeek,
      'dietaryRestrictions': dietaryRestrictions,
      'fitnessGoal': fitnessGoal,
    };
  }
}