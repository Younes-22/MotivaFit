import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_model.dart';
import '../services/firestore_service.dart';

// The main screen for tracking daily fitness. It allows users to log individual exercises or quickly load up their favorite saved routines.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

// Manages the tab navigation between "Today's Log" and "My Plans", and handles all the dialogs for adding new exercises and routines.
class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  final DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Dialogs & actions

  // A dual-purpose dialog. If it's called from the "Create Plan" screen, it passes the exercise back to be bundled into the template. Otherwise, it logs it directly to today.
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
                  Expanded(child: TextField(controller: repsController, decoration: const InputDecoration(labelText: 'Reps (e.g. 8-12)'))),
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

              // Validation: We only strictly require the Name and Sets to prevent empty database entries
              if (name.isNotEmpty && sets > 0) {
                final ex = Exercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  sets: sets,
                  reps: reps.isEmpty ? "0" : reps,
                  weight: weight,
                );

                if (onAdd != null) {
                  onAdd(ex); // Send it back to the Routine Creator
                } else {
                  _firestore.logExercise( // Save it directly to Today's Log
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

  // An interactive builder that lets users bundle multiple exercises into a reusable template (like "Pull Day" or "Leg Day") so they don't have to type them out every week.
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Plan Name (e.g. Pull Day)')),
                const SizedBox(height: 16),
                Text("${tempExercises.length} Exercises Added", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
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

  // Marks today's workout as complete in the database. It then checks if the XP rewarded was enough to push the user to the next level.
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

  // UI builder

  // The main scaffold that sets up the top navigation tabs, allowing the user to swipe back and forth between their active log and their saved templates.
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
          // TAB 1: Today's Log
          _buildTodayTab(),

          // TAB 2: My Plans
          _buildPlansTab(),
        ],
      ),
    );
  }

  // The active workout view. It seamlessly transitions between three states: 
  // 1) An empty prompt to start, 2) The active list of exercises, 3) The victory screen.
  Widget _buildTodayTab() {
    return StreamBuilder<WorkoutDay>(
      stream: _firestore.getWorkoutForDate(_selectedDate),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final workout = snapshot.data!;
        final exercises = workout.exercises;

        // Completion State
        // If the workout is finished, hide the list entirely and show the victory graphic!
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

        // Empty State
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
                  onPressed: () => _tabController.animateTo(1), // Go to plans
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

        // Active Workout State
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
            
            // Allow adding more exercises while actively working out
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
            
            // Finish Button
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

  // Displays all the user's saved workout templates. Tapping the green play button instantly copies all the exercises from the template into today's log.
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
                              _tabController.animateTo(0); // Jump back to the active Log tab
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