import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskDifficulty { easy, medium, hard }
enum TaskPriority { low, normal, high }

class Task {
  final String id;
  final String title;
  final String category;
  final TaskDifficulty difficulty;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime scheduledDate;

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.difficulty,
    required this.priority,
    required this.scheduledDate,
    this.isCompleted = false,
  });

  // The gamification logic
  int get xpReward {
    switch (difficulty) {
      case TaskDifficulty.easy: return 25;
      case TaskDifficulty.medium: return 50;
      case TaskDifficulty.hard: return 80;
    }
  }

  int get coinReward {
    int base;
    switch (difficulty) {
      case TaskDifficulty.easy: base = 10; break;
      case TaskDifficulty.medium: base = 25; break;
      case TaskDifficulty.hard: base = 40; break;
    }
    
    double multiplier;
    switch (priority) {
      case TaskPriority.low: multiplier = 0.8; break;
      case TaskPriority.normal: multiplier = 1.0; break;
      case TaskPriority.high: multiplier = 1.3; break;
    }
    
    return (base * multiplier).round();
  }

  // Firestore serialization
  factory Task.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? 'Untitled',
      category: data['category'] ?? 'General',
      difficulty: _parseDifficulty(data['difficulty']),
      priority: _parsePriority(data['priority']),
      isCompleted: data['isCompleted'] ?? false,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'difficulty': difficulty.name,
      'priority': priority.name,
      'isCompleted': isCompleted,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static TaskDifficulty _parseDifficulty(String? val) {
    return TaskDifficulty.values.firstWhere(
      (e) => e.name == val, orElse: () => TaskDifficulty.easy);
  }

  static TaskPriority _parsePriority(String? val) {
    return TaskPriority.values.firstWhere(
      (e) => e.name == val, orElse: () => TaskPriority.normal);
  }
}