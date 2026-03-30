import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart'; 

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final FirestoreService _firestore = FirestoreService();

  int _currentPage = 0;
  bool _isLoading = false;

  // --- USER DATA VARIABLES ---
  String _gender = 'Male';
  double _age = 25;
  double _weight = 70; // kg
  double _height = 170; // cm
  String _activityLevel = 'Lightly Active';
  String _goal = 'Maintain';
  final List<String> _selectedRestrictions = [];

  final List<String> _dietOptions = ['None', 'Vegan', 'Vegetarian', 'Keto', 'Halal', 'No Nuts', 'Dairy-Free'];

  // --- CALCULATE & SAVE LOGIC ---
  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);

    // 1. Calculate BMR (Mifflin-St Jeor)
    double bmr = (10 * _weight) + (6.25 * _height) - (5 * _age);
    bmr += (_gender == 'Male') ? 5 : -161;

    // 2. Apply Activity Multiplier
    double multiplier;
    switch (_activityLevel) {
      case 'Sedentary': multiplier = 1.2; break;
      case 'Lightly Active': multiplier = 1.375; break;
      case 'Very Active': multiplier = 1.725; break;
      default: multiplier = 1.55; 
    }
    double tdee = bmr * multiplier;

    // 3. Apply Goal Adjustment
    if (_goal == 'Lose Weight') tdee -= 500;
    if (_goal == 'Build Muscle') tdee += 300;

    int targetCalories = tdee.round();

    // 4. Calculate Macros (30% Protein, 40% Carbs, 30% Fat)
    int targetProtein = ((targetCalories * 0.30) / 4).round(); 
    int targetCarbs = ((targetCalories * 0.40) / 4).round();   
    int targetFat = ((targetCalories * 0.30) / 9).round();     

    // 5. Create the base profile FIRST using the safe .set() method
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.createUserProfile(user, 'New Hero');
    }

    // 6. Safely update it with their Onboarding choices
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
    
    // 7. Navigate to Home
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finishOnboarding();
    }
  }

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

  Widget _buildBodyMetricsPage() {
    return _pageTemplate(
      title: "Current Stats",
      child: Column(
        children: [
          Text("Height: ${_height.round()} cm"),
          Slider(
            value: _height,
            min: 120, max: 220, divisions: 100,
            label: _height.round().toString(),
            onChanged: (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 24),
          Text("Weight: ${_weight.round()} kg"),
          Slider(
            value: _weight,
            min: 40, max: 200, divisions: 160,
            label: _weight.round().toString(),
            onChanged: (val) => setState(() => _weight = val),
          ),
        ],
      ),
    );
  }

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