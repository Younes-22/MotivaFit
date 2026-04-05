import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';
import '../models/nutrition_model.dart';

class AIChatService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final GenerativeModel _model;

  AIChatService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash', 
          apiKey: _apiKey,
        );

  Future<String> getMealSuggestion({
    required UserModel user,
    required NutritionDay todayNutrition,
    required String userQuery,
  }) async {
    if (_apiKey.isEmpty) {
      return "Error: API Key is missing. Check your .env file.";
    }

    final remainingCals = user.calorieGoal - todayNutrition.calories;
    
    // --- UPDATED: Grouping everything under one professional term ---
    final dietaryRequirements = user.dietaryRestrictions.join(', ');

    final systemPrompt = """
    You are Mo, the professional AI Nutritionist for the 'MotivaFit' app. 
    
    YOUR SCOPE:
    - You ONLY provide advice regarding meals, recipes, macros, and nutrition.
    - If the user asks about workouts or exercises, politely decline and steer them back to nutrition.
    
    USER CONTEXT:
    - User Name: ${user.username}
    - Dietary Requirements: ${dietaryRequirements.isEmpty ? 'None' : dietaryRequirements}
    - Remaining Daily Calories: $remainingCals
    
    STRICT GUIDELINES:
    1. Always stay in character as 'Mo'.
    2. MANDATORY: You must strictly adhere to the 'Dietary Requirements'. For example, if 'Halal' is listed, never suggest pork or alcohol. If an allergy is listed, never suggest that ingredient.
    3. Ensure suggestions stay within the $remainingCals calorie limit.
    4. Be concise, encouraging, and address ${user.username} by name.
    """;

    try {
      final content = [Content.text("$systemPrompt\n\nUser: $userQuery")];
      final response = await _model.generateContent(content);
      return response.text ?? "I'm sorry, I couldn't generate a suggestion.";
    } catch (e) {
      return "DEBUG ERROR: ${e.toString()}";
    }
  }
}

