import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// A simple blueprint for holding food data. By packaging the name and macros into this single object, it makes it incredibly easy to pass meal data around between different screens in the app without getting numbers mixed up.
class FoodItem {
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

// The engine that connects the app to the massive Spoonacular food database. It handles formatting our requests and cleaning up the raw data that comes back.
class FoodService {
  // Pulling the credentials securely from the hidden .env file
  static final String _apiKey = dotenv.env['SPOONACULAR_API_KEY'] ?? '';

  // Takes whatever the user typed into the search bar, safely encodes it for the web, and asks Spoonacular for the top 15 matches along with their exact nutritional breakdown.
  Future<List<FoodItem>> searchFood(String query) async {
    if (_apiKey.isEmpty) {
      throw Exception("API key missing from .env file");
    }

    try {
      final url = Uri.parse('https://api.spoonacular.com/recipes/complexSearch?query=${Uri.encodeComponent(query)}&addRecipeNutrition=true&number=15&apiKey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        return results.map((item) {
          final nutrition = item['nutrition'] ?? {};
          final nutrients = nutrition['nutrients'] as List? ?? [];
          
          // Spoonacular returns a giant, unpredictable list of every nutrient imaginable. 
          // This helper safely digs through that list to find only the specific macro we want.
          int getNutrient(String name) {
            final nut = nutrients.firstWhere((n) => n['name'] == name, orElse: () => {'amount': 0.0});
            return (nut['amount'] as num).round();
          }

          return FoodItem(
            name: item['title'] ?? 'Unknown Food',
            calories: getNutrient('Calories'),
            protein: getNutrient('Protein'),
            carbs: getNutrient('Carbohydrates'),
            fat: getNutrient('Fat'),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      throw Exception("Failed to connect to Spoonacular.");
    }
  }

  // Pings a completely different Spoonacular database built specifically for store-bought products. It takes the raw barcode number and returns the exact grocery item.
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    if (_apiKey.isEmpty) {
      throw Exception("API key missing from .env file");
    }

    try {
      final url = Uri.parse('https://api.spoonacular.com/food/products/upc/$barcode?apiKey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nutrition = data['nutrition'] ?? {};
        
        // The barcode database returns macros as text strings (like "14g" or "5mg") instead of raw numbers. This helper strips out all the letters so our math doesn't break.
        double parseMacro(String? val) {
          if (val == null) return 0.0;
          final cleanVal = val.replaceAll(RegExp(r'[^0-9.]'), '');
          return double.tryParse(cleanVal) ?? 0.0;
        }

        return FoodItem(
          name: data['title'] ?? 'Unknown Product',
          calories: (nutrition['calories'] ?? 0).round(),
          protein: parseMacro(nutrition['protein']).round(),
          carbs: parseMacro(nutrition['carbs']).round(),
          fat: parseMacro(nutrition['fat']).round(),
        );
      }
      return null; 
    } catch (e) {
      throw Exception("Barcode not found in database.");
    }
  }
}