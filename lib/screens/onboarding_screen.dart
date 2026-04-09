import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart'; 

// The welcoming flow for new users. It gathers basic physical stats and lifestyle choices to personalize their MotivaFit experience right out of the gate.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// Holds all the data the user inputs across the different pages before we finally bundle it up and send it to the database.
class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final FirestoreService _firestore = FirestoreService();

  int _currentPage = 0;
  bool _isLoading = false;

  // User Data Variables
  String _gender = 'Male';
  double _age = 25;
  double _weight = 70; // kg
  double _height = 170; // cm
  String _activityLevel = 'Lightly Active';
  String _goal = 'Maintain';
  final List<String> _selectedRestrictions = [];

  final List<String> _dietOptions = ['None', 'Vegan', 'Vegetarian', 'Keto', 'Halal', 'No Nuts', 'Dairy-Free'];

  // Math function. It takes all the user's answers, runs them through the clinical Mifflin-St Jeor equation to find their baseline metabolic rate, adjusts for their goals, and splits the calories into specific macro targets before saving to Firebase.
  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);

    // Calculate BMR (Mifflin-St Jeor)
    double bmr = (10 * _weight) + (6.25 * _height) - (5 * _age);
    bmr += (_gender == 'Male') ? 5 : -161;

    // Apply Activity Multiplier
    double multiplier;
    switch (_activityLevel) {
      case 'Sedentary': multiplier = 1.2; break;
      case 'Lightly Active': multiplier = 1.375; break;
      case 'Very Active': multiplier = 1.725; break;
      default: multiplier = 1.55; 
    }
    double tdee = bmr * multiplier;

    // Apply Goal Adjustment
    if (_goal == 'Lose Weight') tdee -= 500;
    if (_goal == 'Build Muscle') tdee += 300;

    int targetCalories = tdee.round();

    // Calculate Macros (30% Protein, 40% Carbs, 30% Fat)
    int targetProtein = ((targetCalories * 0.30) / 4).round(); 
    int targetCarbs = ((targetCalories * 0.40) / 4).round();   
    int targetFat = ((targetCalories * 0.30) / 9).round();     

    // Create the base profile FIRST using the safe .set() method
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.createUserProfile(user, 'New Hero');
    }

    // Safely update it with their Onboarding choices
    await _firestore.updateDietaryPreferences(
      restrictions: _selectedRestrictions.contains('None') ? [] : _selectedRestrictions,
      goal: _goal,
    );
    
    await _firestore.updateNutritionGoals(
      calories: targetCalories,
      protein: targetProtein,
      carbs: targetCarbs,
      fat: targetFat,
    );

    if (!mounted) return;
    setState(() => _isLoading = false); // Stop the loading spinner

    showDialog(
      context: context,
      barrierDismissible: false, // Force them to click the button to continue
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.analytics, size: 48, color: Colors.deepPurple),
        title: const Text('Your Plan is Ready!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Based on clinical formulas, we've calculated the optimal fuel for your mission:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(Icons.local_fire_department, "Calories", "$targetCalories kcal/day", Colors.orange),
            _buildSummaryRow(Icons.fitness_center, "Protein", "${targetProtein}g", Colors.blue),
            _buildSummaryRow(Icons.bakery_dining, "Carbs", "${targetCarbs}g", Colors.amber),
            _buildSummaryRow(Icons.water_drop, "Fat", "${targetFat}g", Colors.purple),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                // Navigate to Home
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              },
              child: const Text("Let's Go!"),
            ),
          ),
        ],
      ),
    );
  }

  // A clean, reusable UI row to display the final calculated macros in the pop-up dialog.
  Widget _buildSummaryRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // Moves the user to the next question in the form, or kicks off the final calculation if they are currently on the last page.
  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finishOnboarding();
    }
  }

  // The main scaffold. It shows a progress bar at the top so the user knows how many questions are left, and anchors the main action button at the bottom.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hero Setup"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentPage + 1) / 4, color: Colors.amber),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), 
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildBasicStatsPage(),
                _buildBodyMetricsPage(),
                _buildLifestylePage(),
                _buildDietPage(),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _nextPage,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_currentPage == 3 ? "BEGIN JOURNEY" : "NEXT"),
              ),
            ),
          )
        ],
      ),
    );
  }

  // Page 1: Grabs biological sex and age, which are crucial variables for the BMR calculation.
  Widget _buildBasicStatsPage() {
    return _pageTemplate(
      title: "Who is our hero?",
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Biological Sex (For calculations)'),
            items: ['Male', 'Female'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (val) => setState(() => _gender = val!),
          ),
          const SizedBox(height: 24),
          Text("Age: ${_age.round()} years"),
          Slider(
            value: _age,
            min: 14, max: 100, divisions: 86,
            label: _age.round().toString(),
            onChanged: (val) => setState(() => _age = val),
          ),
        ],
      ),
    );
  }

  // Page 2: Grabs height and weight using sliders for a more interactive, tap-friendly experience.
  Widget _buildBodyMetricsPage() {
    return _pageTemplate(
      title: "Current Stats",
      child: Column(
        children: [
          Text("Height: ${_height.round()} cm"),
          Slider(
            value: _height,
            // Highly inclusive height range
            min: 50, max: 250, divisions: 200, 
            label: _height.round().toString(),
            onChanged: (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 24),
          Text("Weight: ${_weight.round()} kg"),
          Slider(
            value: _weight,
            // Highly inclusive weight range
            min: 20, max: 300, divisions: 280, 
            label: _weight.round().toString(),
            onChanged: (val) => setState(() => _weight = val),
          ),
        ],
      ),
    );
  }

  // Page 3: Determines the activity multiplier and whether we need to add/subtract calories for muscle gain or weight loss.
  Widget _buildLifestylePage() {
    return _pageTemplate(
      title: "The Mission",
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(labelText: 'Current Activity Level'),
            items: ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'].map((String val) {
              return DropdownMenuItem<String>(value: val, child: Text(val));
            }).toList(),
            onChanged: (val) => setState(() => _activityLevel = val!),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _goal,
            decoration: const InputDecoration(labelText: 'Primary Goal'),
            items: ['Lose Weight', 'Maintain', 'Build Muscle'].map((String val) {
              return DropdownMenuItem<String>(value: val, child: Text(val));
            }).toList(),
            onChanged: (val) => setState(() => _goal = val!),
          ),
        ],
      ),
    );
  }

  // Page 4: Lets the user pick multiple dietary restrictions using toggleable chips.
  Widget _buildDietPage() {
    return _pageTemplate(
      title: "Any Dietary Rules?",
      child: Wrap(
        spacing: 8.0,
        children: _dietOptions.map((diet) {
          final isSelected = _selectedRestrictions.contains(diet);
          return FilterChip(
            label: Text(diet),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (diet == 'None') {
                  _selectedRestrictions.clear();
                  if (selected) _selectedRestrictions.add('None');
                } else {
                  _selectedRestrictions.remove('None');
                  selected ? _selectedRestrictions.add(diet) : _selectedRestrictions.remove(diet);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  // A wrapper widget that ensures every question page shares the exact same title styling and spacing.
  Widget _pageTemplate({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }
}