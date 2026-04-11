import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_model.dart';
import '../services/firestore_service.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _showAddExerciseDialog(BuildContext context, {Function(Exercise)? onAdd}) {
    final nameController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final weightController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Exercise Name')),
              Row(
                children: [
                  Expanded(child: TextField(controller: setsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sets'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: repsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reps (e.g. 8-12)'))),
                ],
              ),
              TextField(controller: weightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight (kg)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final sets = int.tryParse(setsController.text) ?? 0;
              final reps = repsController.text.trim();
              final weight = double.tryParse(weightController.text) ?? 0.0;

              if (name.isNotEmpty && sets > 0) {
                final ex = Exercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  sets: sets,
                  reps: reps.isEmpty ? "0" : reps,
                  weight: weight,
                );

                if (onAdd != null) {
                  onAdd(ex); 
                } else {
                  _firestore.logExercise( 
                    name: name, sets: sets, reps: reps, weight: weight, date: _selectedDate
                  );
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameController = TextEditingController();
    List<Exercise> tempExercises = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Workout Plan'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Plan Name (e.g. Pull Day)')),
                  const SizedBox(height: 16),
                  Text("${tempExercises.length} Exercises Added", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tempExercises.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      title: Text(tempExercises[index].name),
                      subtitle: Text("${tempExercises[index].sets} x ${tempExercises[index].reps}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () => setState(() => tempExercises.removeAt(index)),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
                    onPressed: () => _showAddExerciseDialog(context, onAdd: (ex) {
                      setState(() => tempExercises.add(ex));
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && tempExercises.isNotEmpty) {
                  _firestore.createRoutine(nameController.text, tempExercises);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan Created!')));
                }
              },
              child: const Text('Save Plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _finishWorkout(BuildContext context) async {
    bool leveledUp = await _firestore.finishWorkout(_selectedDate);
    if (!context.mounted) return;

    if (leveledUp) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('🎉 LEVEL UP!'),
          content: const Text('Workout Complete! You are getting stronger!'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Let\'s Go!'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout Finished! +100 XP, +20 Coins'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Today's Log"), Tab(text: "My Plans")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayTab(),
          _buildPlansTab(),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    return StreamBuilder<WorkoutDay>(
      stream: _firestore.getWorkoutForDate(_selectedDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final workout = snapshot.data!;
        final exercises = workout.exercises;

        if (workout.isCompleted) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                const SizedBox(height: 24),
                const Text(
                  "Workout Complete!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                Text(
                  "You crushed it today.\nXP and Coins have been awarded!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        if (exercises.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("No exercises yet."),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Load a Plan'),
                ),
                TextButton(
                  onPressed: () => _showAddExerciseDialog(context),
                  child: const Text('Or add single exercise'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exercises.length,
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  return Card(
                    child: ListTile(
                      title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${ex.sets} sets x ${ex.reps} reps @ ${ex.weight}kg"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _firestore.deleteExercise(_selectedDate, ex),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton.icon(
                onPressed: () => _showAddExerciseDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Another Exercise'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () => _finishWorkout(context),
                child: const Text('FINISH WORKOUT (Claim Reward)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlansTab() {
    return StreamBuilder<List<WorkoutRoutine>>(
      stream: _firestore.getRoutines(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final routines = snapshot.data!;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCreatePlanDialog(context),
            label: const Text('Create Plan'),
            icon: const Icon(Icons.add),
          ),
          body: routines.isEmpty 
            ? const Center(child: Text("No plans created yet."))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: routines.length,
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${routine.exercises.length} Exercises"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            tooltip: "Start this workout",
                            onPressed: () {
                              _firestore.loadRoutineIntoToday(routine, _selectedDate);
                              _tabController.animateTo(0); 
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan Loaded!')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey),
                            onPressed: () => _firestore.deleteRoutine(routine.id),
                          ),
                        ],
                      ),
                      children: routine.exercises.map((e) => ListTile(
                        dense: true,
                        title: Text(e.name),
                        trailing: Text("${e.sets} x ${e.reps}"),
                      )).toList(),
                    ),
                  );
                },
              ),
        );
      },
    );
  }
}