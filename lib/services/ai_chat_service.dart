import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_model.dart';
import '../models/nutrition_model.dart';

class AIChatService {
  
  Future<String> getMealSuggestion({
    required UserModel user,
    required NutritionDay todayNutrition,
    required List<Map<String, String>> chatHistory,
  }) async {
    
    int remainingCals = user.calorieGoal - todayNutrition.calories;
    int remainingProtein = user.proteinGoal - todayNutrition.protein;
    int remainingCarbs = user.carbsGoal - todayNutrition.carbs;
    int remainingFat = user.fatGoal - todayNutrition.fat;
    
    String dietText = user.dietaryRestrictions.isEmpty 
        ? 'None' 
        : user.dietaryRestrictions.join(', ');

    // The System Prompt
    final String systemPrompt = """
You are Mo, the professional and friendly AI Nutritionist for the 'MotivaFit' app.

YOUR SCOPE:
- You ONLY provide advice regarding meals, recipes, macros, and nutrition.
- If the user asks about workouts or exercises, politely decline and steer them back to nutrition.

USER CONTEXT:
- User Name: ${user.username}
- Dietary Requirements: $dietText
- Remaining Daily Calories: $remainingCals kcal
- Remaining Macros: $remainingProtein g Protein, $remainingCarbs g Carbs, $remainingFat g Fat
  *(Note: If any remaining calorie or macro values are negative, it means the user has gone OVER their limit for that specific nutrient today. Adjust your advice accordingly).*

STRICT GUIDELINES:
1. Always stay in character as 'Mo'.
2. MANDATORY: You must strictly adhere to the 'Dietary Requirements'. For example, if 'Halal' or 'Vegan' is listed, never suggest violating it. 
3. Ensure any meal suggestions mathematically fit within the remaining calories and macros provided above.
4. Keep your response concise, using line breaks or emojis for quick readability.
5. CONVERSATIONAL FLOW & QUESTIONS:
   - GREETINGS: If the user simply says "hi" or "hello," warmly greet them back and ask how you can help them with their nutrition today.
   - REJECTIONS: If the user dislikes a meal suggestion, DO NOT blindly guess another one. Instead, ask them what ingredients they have on hand or what type of food they are craving.
   - CALL TO ACTION: Ask follow-up questions *only* when appropriate to move the conversation forward (e.g., "Would you like the recipe for this?"). If the user's goal is complete, simply offer a supportive sign-off.
""";

    try {
      // Primary API: Hugging Face with full conversational memory
      return await _callHuggingFace(systemPrompt, chatHistory);
      
    } catch (e) {
      print("Hugging Face failed. Falling back to Gemini...");
      print("HF ERROR: $e");
      
      try {
        // Backup API: Gemini
        return await _callGemini(systemPrompt, chatHistory, user.username);
        
      } catch (backupError) {
        print("GEMINI ERROR: $backupError");
        return "Mo is currently overwhelmed helping other users! Both of my brain servers are taking a breather. Please try again in a few minutes. ⏳";
      }
    }
  }

  // PRIMARY API: Hugging Face (OpenAI gpt-oss-20b)
  Future<String> _callHuggingFace(String systemPrompt, List<Map<String, String>> chatHistory) async {
    final apiKey = dotenv.env['HUGGING_FACE_API_KEY'];
    if (apiKey == null) throw Exception("Hugging Face API key missing");

    // 1. Start the payload with Mo's strict instructions
    List<Map<String, String>> formattedMessages = [
      {"role": "system", "content": systemPrompt}
    ];

    // 2. Loop through the Flutter chat history and translate it into OpenAI format
    for (var msg in chatHistory) {
      formattedMessages.add({
        "role": msg['role'] == 'bot' ? 'assistant' : 'user', // Translate 'bot' to 'assistant'
        "content": msg['text'] ?? ""
      });
    }

    final url = Uri.parse('https://router.huggingface.co/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "openai/gpt-oss-20b",
        "messages": formattedMessages, // Pass the entire conversation!
        "max_tokens": 300, 
        "stream": false
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception('Hugging Face Error: ${response.statusCode}');
    }
  }

  // BACKUP API: Google Gemini
  Future<String> _callGemini(String systemPrompt, List<Map<String, String>> chatHistory, String username) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) throw Exception("Gemini API key missing");

    // Gemini's API crashes if you send it history in the wrong order (e.g. Model -> User instead of User -> Model).
    // To make this 100% crash-proof for our fallback, we format the history into a raw text transcript instead.
    String transcript = "$systemPrompt\n\n--- CONVERSATION HISTORY ---\n";
    
    for (var msg in chatHistory) {
      String speaker = msg['role'] == 'user' ? username : "Mo";
      transcript += "$speaker: ${msg['text']}\n\n";
    }
    
    transcript += "Mo:"; // Prompt Gemini to generate Mo's next reply

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final response = await model.generateContent([Content.text(transcript)]);
    
    return response.text ?? "";
  }
}