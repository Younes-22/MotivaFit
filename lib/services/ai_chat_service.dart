import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';
import '../models/nutrition_model.dart';

// This service acts as the brain behind Mo, our AI nutritionist. It securely talks to the Google Gemini API to generate personalized meal advice.
class AIChatService {
  // We pull the sensitive API key from a hidden .env file so it never accidentally gets uploaded to public repositories like GitHub.
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final GenerativeModel _model;

  // Initializes the specific Gemini model we want to use. The 'flash' model is incredibly fast and perfect for real-time chat interfaces.
  AIChatService()
      : _model = GenerativeModel(
          model: 'gemini-2.5-flash', 
          apiKey: _apiKey,
        );

  // Takes the user's current daily progress and their profile data, bundles it into a strict set of instructions, and sends the user's question to the AI.
  Future<String> getMealSuggestion({
    required UserModel user,
    required NutritionDay todayNutrition,
    required String userQuery,
  }) async {
    // Safety check just in case the .env file wasn't set up properly
    if (_apiKey.isEmpty) {
      return "Error: API Key is missing. Check your .env file.";
    }

    // Figure out exactly how much food they can still eat today
    final remainingCals = user.calorieGoal - todayNutrition.calories;
    
    // Convert the list of restrictions (e.g. ['Vegan', 'Keto']) into a readable comma-separated string
    final dietaryRequirements = user.dietaryRestrictions.join(', ');

    // This 'System Prompt' is essentially the rulebook for the AI. It tells Gemini exactly who to act like, what real-time data to respect, and what topics to avoid.
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
      // Bundle our hidden instructions and the user's actual question together
      final content = [Content.text("$systemPrompt\n\nUser: $userQuery")];
      
      // Wait for Gemini to think and respond
      final response = await _model.generateContent(content);
      return response.text ?? "I'm sorry, I couldn't generate a suggestion.";
    } catch (e) {
      return "DEBUG ERROR: ${e.toString()}";
    }
  }
}