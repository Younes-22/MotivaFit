import 'package:cloud_firestore/cloud_firestore.dart';

class NutritionDay {
  final String id; // Format will be in YYYY-MM-DD
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final DateTime date;

  NutritionDay({
    required this.id,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
  });

  // Calculate  progress
  double getCalorieProgress(int goal) {
    if (goal == 0) return 0.0;
    return (calories / goal).clamp(0.0, 1.0);
  }

  factory NutritionDay.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NutritionDay(
      id: doc.id,
      calories: data['calories'] ?? 0,
      protein: data['protein'] ?? 0,
      carbs: data['carbs'] ?? 0,
      fat: data['fat'] ?? 0,
      date: (data['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': Timestamp.fromDate(date),
    };
  }
}