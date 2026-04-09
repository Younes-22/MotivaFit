import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutDay {
  final String id;
  final DateTime date;
  final List<Exercise> exercises;
  final bool isCompleted; // Track if they clicked "Finish Workout"

  WorkoutDay({
    required this.id,
    required this.date,
    required this.exercises,
    this.isCompleted = false,
  });

  factory WorkoutDay.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkoutDay(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      exercises: (data['exercises'] as List<dynamic>?)
          ?.map((e) => Exercise.fromMap(e))
          .toList() ?? [],
      isCompleted: data['isCompleted'] ?? false,
    );
  }
}

class WorkoutRoutine {
  final String id;
  final String name; // Push Day for example
  final List<Exercise> exercises;

  WorkoutRoutine({required this.id, required this.name, required this.exercises});

  factory WorkoutRoutine.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkoutRoutine(
      id: doc.id,
      name: data['name'] ?? 'Untitled Routine',
      exercises: (data['exercises'] as List<dynamic>?)
          ?.map((e) => Exercise.fromMap(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }
}

class Exercise {
  final String id;
  final String name;
  final int sets;
  final String reps;
  final double weight;

  Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? '',
      sets: map['sets'] ?? 0,
      reps: map['reps'] ?? '0',
      weight: (map['weight'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sets': sets,
      'reps': reps,
      'weight': weight,
    };
  }
}