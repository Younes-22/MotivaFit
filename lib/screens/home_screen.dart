import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart'; 
import '../models/task_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/task_tile.dart';
import '../widgets/quote_widget.dart'; 
import '../widgets/completion_chart.dart'; 
import '../widgets/boss_battle_card.dart'; 
import 'add_task_screen.dart';
import 'shop_screen.dart';
import 'settings_screen.dart';
import 'nutrition_screen.dart'; 
import 'workout_screen.dart';   
import 'trophy_room_screen.dart';

// The main dashboard of the app. This ties together the user's progress, the weekly boss, the calendar, and the daily task list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Keeps track of which tasks are currently saving to the database. 
  // We use this to show a loading spinner on the checkbox to prevent double-clicking.
  final Set<String> _updatingTaskIds = {}; 
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week; 

  @override
  void initState() {
    super.initState();
    // As soon as the home screen loads, quietly check in the background if a new day has started so we can reset daily tasks and apply any missed-task penalties.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runDailyCheck();
    });
  }

  void _runDailyCheck() async {
    final firestore = FirestoreService();
    final summary = await firestore.checkDailyRollover();

    if (summary != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Daily Summary'),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // A celebratory pop-up that triggers if checking off a task pushes the user over the XP threshold
  void _showLevelUpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
        title: const Text('LEVEL UP!', textAlign: TextAlign.center),
        content: const Text(
          'Congratulations! You have reached the next level. Keep up the great work!',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('AWESOME!'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Preferred Name"),
        content: TextField(
          controller: nameController,
          maxLength: 15,
          decoration: const InputDecoration(
            hintText: "What should we call you?",
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                FirestoreService().updateUsername(nameController.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  String get _formattedDate {
    final now = DateTime.now();
    final List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _navigateToAddTask(BuildContext context, {String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          initialCategory: category,
          initialDate: _selectedDay, 
        ),
      ),
    );
  }

  // Flips a task between completed/uncompleted, saves it to Firestore, and checks if the rewards earned caused a level up.
  Future<void> _handleTaskToggle(Task task, bool newValue, FirestoreService firestore) async {
    setState(() {
      _updatingTaskIds.add(task.id);
    });

    try {
      bool didLevelUp = await firestore.toggleTaskCompletion(task, newValue);

      if (didLevelUp && mounted) {
        _showLevelUpDialog();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingTaskIds.remove(task.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: StreamBuilder<UserModel>(
                      stream: firestore.getUserStream(),
                      builder: (context, snapshot) {
                        String displayName = "Hero"; 
                        
                        if (snapshot.hasData) {
                          displayName = snapshot.data!.username;
                        }

                        return GestureDetector(
                          onTap: () => _showEditNameDialog(displayName),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome',
                                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    Text(
                                      displayName,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.edit, size: 16, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 16), 
                  
                  // specific material icons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Trophy Room",
                        icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrophyRoomScreen())),
                      ),
                      IconButton(
                        tooltip: "Item Shop",
                        icon: const Icon(Icons.store, color: Colors.deepPurple, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
                      ),
                      IconButton(
                        tooltip: "Settings",
                        icon: const Icon(Icons.settings, size: 28),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              const QuoteWidget(), 

              const SizedBox(height: 24),

              // The gamification section. Shows the user's personal XP/Level progress, followed by the current state of the global weekly boss battle.
              StreamBuilder<UserModel>(
                stream: firestore.getUserStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const SizedBox.shrink(); 
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final user = snapshot.data!;
                  double progress = user.currentXP / 500.0;
                  
                  return Column(
                    children: [
                      ProgressCard(
                        level: user.currentLevel,
                        currentXP: user.currentXP,
                        currentCoins: user.currentCoins,
                        progress: progress,
                        selectedAvatarId: user.selectedAvatarId, 
                      ),
                      const SizedBox(height: 24),
                      BossBattleCard(user: user),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Shortcuts to the most commonly used screens in the app
              Text('Quick Actions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context, 
                          Icons.directions_run, 
                          'Log Workout', 
                          Colors.orange, 
                          'Workout',
                          onPressedOverride: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const WorkoutScreen())
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          context, 
                          Icons.restaurant, 
                          'Log Meal', 
                          Colors.green, 
                          'Nutrition',
                          onPressedOverride: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const NutritionScreen())
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      context, 
                      Icons.add, 
                      'Custom Task', 
                      Colors.purple, 
                      'Custom',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // The interactive weekly calendar. Clicking a day updates the _selectedDay variable, which automatically forces the task list below it to fetch new data.
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: TableCalendar(
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 24), 

              const CompletionChart(),

              const SizedBox(height: 16),

              // Real-time list of tasks specifically for the day chosen on the calendar above
              StreamBuilder<List<Task>>(
                stream: firestore.getTasksForDay(_selectedDay), 
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final tasks = snapshot.data ?? [];

                  if (tasks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "No tasks for this day.\nTap '+' to add one!",
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskTile(
                        task: task,
                        isUpdating: _updatingTaskIds.contains(task.id), 
                        onChanged: (val) {
                          if (val != null) {
                            _handleTaskToggle(task, val, firestore);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A helper method used to quickly build those large, colorful Quick Action buttons
  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, String category, {VoidCallback? onPressedOverride}) {
    return Container(
      height: 60, 
      decoration: BoxDecoration(
        // We use .withValues() instead of the old .withOpacity() because Flutter updated how it handles wide-gamut colors (like on newer iPhones) to prevent visual bugs.
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onPressedOverride ?? () => _navigateToAddTask(context, category: category),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}