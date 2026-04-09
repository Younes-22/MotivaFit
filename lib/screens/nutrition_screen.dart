import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; 
import '../models/user_model.dart';
import '../models/nutrition_model.dart';
import '../services/firestore_service.dart';
import '../services/food_service.dart';
import 'ai_chat_screen.dart';

// The main hub for tracking meals. It handles barcode scanning, searching a public food database, and calculating daily macro goals.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final FoodService _foodService = FoodService();
  bool _isSearching = false;
  
  // This timer stops the app from spamming the food database every time the user types a single letter. It waits until they pause typing before searching.
  Timer? _debounce; 

  // Opens the device camera to look for a barcode. If it finds one, it sends the number to our food database to find the exact product.
  Future<void> _scanBarcode(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          bool isScanned = false; 
          return Scaffold(
            appBar: AppBar(title: const Text('Scan Barcode')),
            body: MobileScanner(
              overlayBuilder: (context, constraints) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 150),
                  child: const Center(
                    child: Text(
                      'Align Code Here', 
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    ),
                  ),
                );
              },
              onDetect: (capture) {
                if (isScanned) return; 
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    isScanned = true; 
                    Navigator.pop(context, code); 
                  }
                }
              },
            ),
          );
        },
      ),
    );

    if (result != null && result is String) {
      setState(() => _isSearching = true);
      try {
        // If the public food database is down or slow, we force a timeout after 10 seconds so the user isn't staring at a frozen loading screen forever.
        final food = await _foodService.getFoodByBarcode(result).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Server took too long. Try Manual Entry!"),
        );
        
        if (mounted && food != null) {
          _showLogFoodDialog(context, initialFood: food);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found. Try Manual Entry!'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString().replaceAll("Exception: ", "");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    }
  }

  // Pops up a small search bar where users can type a food name or choose to enter it manually.
  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log a Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search Food Name',
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx); 
                _performSearch(context, val);
              },
            ),
            const SizedBox(height: 20),
            const Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Enter Manually'),
              onPressed: () {
                Navigator.pop(ctx);
                _showManualEntryDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performSearch(context, searchController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // Reaches out to the public API to find food matching the user's search query.
  void _performSearch(BuildContext context, String query) async {
    if (query.trim().isEmpty) return;

    // Reset the timer. If they type another letter before 500ms is up, the timer restarts.
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);

      try {
        final results = await _foodService.searchFood(query).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception("Server is busy or rate-limiting. Try Manual Entry!"),
        );

        if (!mounted) return;
        setState(() => _isSearching = false);

        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No results found (Server might be rate-limiting). Try Manual Entry!'), 
              backgroundColor: Colors.orange
            )
          );
          return;
        }

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Results for "$query"'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final food = results[index];
                  return ListTile(
                    title: Text(food.name),
                    subtitle: Text('${food.calories} kcal / 100g'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showLogFoodDialog(context, initialFood: food);
                    },
                  );
                },
              ),
            ),
          ),
        );

      } catch (e) {
        if (!mounted) return;
        setState(() => _isSearching = false);
        
        final errorMsg = e.toString().replaceAll("Exception: ", "");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    });
  }

  // A bottom sheet that slides up allowing the user to bypass the database and just type in their own custom meal numbers.
  void _showManualEntryDialog() {
    final nameController = TextEditingController();
    final calController = TextEditingController();
    final proController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24, right: 24, top: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Manual Meal Entry", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Meal Name")),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: calController, decoration: const InputDecoration(labelText: "Calories"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: proController, decoration: const InputDecoration(labelText: "Protein (g)"), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: carbController, decoration: const InputDecoration(labelText: "Carbs (g)"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: fatController, decoration: const InputDecoration(labelText: "Fat (g)"), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (calController.text.isEmpty || nameController.text.isEmpty) return;
                    
                    bool leveledUp = await FirestoreService().logFood(
                      calories: int.tryParse(calController.text) ?? 0,
                      protein: int.tryParse(proController.text) ?? 0,
                      carbs: int.tryParse(carbController.text) ?? 0,
                      fat: int.tryParse(fatController.text) ?? 0,
                      date: DateTime.now(),
                    );
                    
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _handleLoggingOutcome(leveledUp);
                  }, 
                  child: const Text("Log Manual Meal")
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Shows the user the food they found. If they change the serving size (e.g. from 100g to 200g), it automatically multiplies all the macros so they don't have to do the math in their head.
  void _showLogFoodDialog(BuildContext context, {FoodItem? initialFood}) {
    final servingController = TextEditingController(text: '100');
    final calController = TextEditingController(text: initialFood?.calories.toString() ?? '');
    final protController = TextEditingController(text: initialFood?.protein.toString() ?? '');
    final carbController = TextEditingController(text: initialFood?.carbs.toString() ?? '');
    final fatController = TextEditingController(text: initialFood?.fat.toString() ?? '');

    void recalculateMacros() {
      if (initialFood == null) return;
      final amount = double.tryParse(servingController.text) ?? 0.0;
      final multiplier = amount / 100.0;
      calController.text = (initialFood.calories * multiplier).round().toString();
      protController.text = (initialFood.protein * multiplier).round().toString();
      carbController.text = (initialFood.carbs * multiplier).round().toString();
      fatController.text = (initialFood.fat * multiplier).round().toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log: ${initialFood?.name ?? "Meal"}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: servingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (g/ml)', suffixText: 'g'),
                onChanged: (_) => recalculateMacros(), 
              ),
              const Divider(height: 32),
              TextField(controller: calController, decoration: const InputDecoration(labelText: 'Calories (kcal)'), keyboardType: TextInputType.number),
              TextField(controller: protController, decoration: const InputDecoration(labelText: 'Protein (g)'), keyboardType: TextInputType.number),
              TextField(controller: carbController, decoration: const InputDecoration(labelText: 'Carbs (g)'), keyboardType: TextInputType.number),
              TextField(controller: fatController, decoration: const InputDecoration(labelText: 'Fat (g)'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              bool leveledUp = await FirestoreService().logFood(
                calories: int.tryParse(calController.text) ?? 0,
                protein: int.tryParse(protController.text) ?? 0,
                carbs: int.tryParse(carbController.text) ?? 0,
                fat: int.tryParse(fatController.text) ?? 0,
                date: DateTime.now()
              );
              if (!mounted) return;
              Navigator.pop(ctx); 
              _handleLoggingOutcome(leveledUp);
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }

  // Gamification check: if eating this meal pushed the user's XP over the threshold, throw a big celebratory popup! Otherwise, just show a quiet success banner.
  void _handleLoggingOutcome(bool leveledUp) {
    if (leveledUp) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
          title: const Text('🎉 LEVEL UP! 🎉'),
          content: const Text('You logged a meal and reached the next level!'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal Logged! (+10 XP, +2 Coins)'), backgroundColor: Colors.green)
      );
    }
  }

  void _showEditGoalsDialog(BuildContext context, UserModel user) {
    final calController = TextEditingController(text: user.calorieGoal.toString());
    final protController = TextEditingController(text: user.proteinGoal.toString());
    final carbController = TextEditingController(text: user.carbsGoal.toString());
    final fatController = TextEditingController(text: user.fatGoal.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: calController, decoration: const InputDecoration(labelText: 'Daily Calories'), keyboardType: TextInputType.number),
            TextField(controller: protController, decoration: const InputDecoration(labelText: 'Protein Goal (g)'), keyboardType: TextInputType.number),
            TextField(controller: carbController, decoration: const InputDecoration(labelText: 'Carbs Goal (g)'), keyboardType: TextInputType.number),
            TextField(controller: fatController, decoration: const InputDecoration(labelText: 'Fat Goal (g)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              FirestoreService().updateNutritionGoals(
                calories: int.tryParse(calController.text) ?? 2000,
                protein: int.tryParse(protController.text) ?? 150,
                carbs: int.tryParse(carbController.text) ?? 200,
                fat: int.tryParse(fatController.text) ?? 70,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Tracker'),
        actions: [
          // AI CITATION: The idea to use the 'psychology' icon to represent an AI brain/assistant was generated by AI.
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.deepPurple),
            tooltip: "Ask AI Nutritionist",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())),
          ),
          StreamBuilder<UserModel>(
            stream: firestore.getUserStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditGoalsDialog(context, snapshot.data!),
              );
            },
          )
        ],
      ),
      body: _isSearching 
        ? const Center(child: CircularProgressIndicator()) 
        : StreamBuilder<UserModel>(
        stream: firestore.getUserStream(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = userSnapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Weekly History", style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildWeeklyGraph(firestore, user.calorieGoal, theme),
                const SizedBox(height: 32),
                Text("Today's Summary", style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _buildTodaySummary(firestore, user, theme),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "scanBtn",
            onPressed: () => _scanBarcode(context),
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "addBtn",
            onPressed: () => _showSearchDialog(context),
            label: const Text('Log Meal'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // AI CITATION: This entire custom bar chart logic—calculating dates, managing heights with FractionallySizedBox, and stacking containers to avoid relying on external plugins—was generated by AI.
  Widget _buildWeeklyGraph(FirestoreService firestore, int goal, ThemeData theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: StreamBuilder<List<NutritionDay>>(
        stream: firestore.getWeeklyNutrition(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final days = snapshot.data!;
          final now = DateTime.now();
          final List<Widget> bars = [];
          for (int i = 6; i >= 0; i--) {
            final date = now.subtract(Duration(days: i));
            final dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            final dayData = days.firstWhere((d) => d.id == dateId, orElse: () => NutritionDay(id: dateId, calories: 0, protein: 0, carbs: 0, fat: 0, date: date));
            double percent = goal == 0 ? 0 : (dayData.calories / goal).clamp(0.0, 1.0);
            bool isToday = i == 0;
            bars.add(Expanded(child: Column(children: [
              Expanded(child: Stack(alignment: Alignment.bottomCenter, children: [
                Container(width: 12, color: Colors.grey.withValues(alpha: 0.2)),
                FractionallySizedBox(heightFactor: percent, child: Container(width: 12, decoration: BoxDecoration(color: isToday ? theme.colorScheme.primary : Colors.grey, borderRadius: BorderRadius.circular(4)))),
              ])),
              const SizedBox(height: 8),
              Text(DateFormat.E().format(date)[0], style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? theme.colorScheme.primary : Colors.grey)),
            ])));
          }
          return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: bars);
        },
      ),
    );
  }

  Widget _buildTodaySummary(FirestoreService firestore, UserModel user, ThemeData theme) {
    return StreamBuilder<NutritionDay>(
      stream: firestore.getNutritionForDate(DateTime.now()),
      builder: (context, snapshot) {
        final data = snapshot.data ?? NutritionDay(id: '', calories: 0, protein: 0, carbs: 0, fat: 0, date: DateTime.now());
        return Column(children: [
          Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Calories", style: TextStyle(fontWeight: FontWeight.bold)), Text("${data.calories} / ${user.calorieGoal} kcal")]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: user.calorieGoal == 0 ? 0 : (data.calories / user.calorieGoal).clamp(0.0, 1.0), minHeight: 12, borderRadius: BorderRadius.circular(6), backgroundColor: Colors.grey.shade200, color: data.calories > user.calorieGoal ? Colors.red : Colors.green),
          ]))),
          const SizedBox(height: 12),
          Row(children: [
            _buildMacroCard("Protein", data.protein, user.proteinGoal, Colors.blue),
            const SizedBox(width: 8),
            _buildMacroCard("Carbs", data.carbs, user.carbsGoal, Colors.orange),
            const SizedBox(width: 8),
            _buildMacroCard("Fat", data.fat, user.fatGoal, Colors.purple),
          ]),
        ]);
      },
    );
  }

  // AI CITATION: The layout of these specific macro cards—wrapping a CircularProgressIndicator around a percentage text inside a stacked box—was designed by AI.
  Widget _buildMacroCard(String label, int current, int goal, Color color) {
    return Expanded(child: Card(color: color.withValues(alpha: 0.1), elevation: 0, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      SizedBox(height: 40, width: 40, child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: goal == 0 ? 0 : (current / goal).clamp(0.0, 1.0), color: color, backgroundColor: Colors.white),
        Text("${goal == 0 ? 0 : (current / goal * 100).toInt()}%", style: const TextStyle(fontSize: 10)),
      ])),
      const SizedBox(height: 8),
      FittedBox(child: Text("$current / ${goal}g", style: const TextStyle(fontSize: 12))),
    ]))));
  }
} 