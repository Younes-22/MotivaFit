import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// A simple blueprint for holding food data. By packaging the name and macros 
// into this single object, it makes it incredibly easy to pass meal data 
// around between different screens in the app without getting numbers mixed up.
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

// The engine that connects the app to the massive Edamam food database. 
// It handles formatting our requests and translating their clinical nutrient codes 
// into simple numbers our app can understand.
class FoodService {
  // Pulling credentials securely from the hidden .env file
  static final String _appId = dotenv.env['EDAMAM_APP_ID'] ?? '';
  static final String _appKey = dotenv.env['EDAMAM_APP_KEY'] ?? '';

  // Takes whatever the user typed into the search bar, safely encodes it for the web, 
  // and asks Edamam for a list of matching foods.
  Future<List<FoodItem>> searchFood(String query) async {
    if (_appId.isEmpty || _appKey.isEmpty) {
      throw Exception("API keys missing from .env file");
    }

    try {
      final url = Uri.parse('https://api.edamam.com/api/food-database/v2/parser?app_id=$_appId&app_key=$_appKey&ingr=${Uri.encodeComponent(query)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Edamam stores search results inside an array called 'hints'
        final List hints = data['hints'] ?? [];
        
        return hints.map((hint) {
          final food = hint['food'] ?? {};
          final nutrients = food['nutrients'] ?? {};
          
          return FoodItem(
            name: food['label'] ?? 'Unknown Food',
            // Edamam uses specific codes for macros: ENERC_KCAL = Calories, PROCNT = Protein, CHOCDF = Carbs, FAT = Fat
            calories: (nutrients['ENERC_KCAL'] ?? 0).round(),
            protein: (nutrients['PROCNT'] ?? 0).round(),
            carbs: (nutrients['CHOCDF'] ?? 0).round(),
            fat: (nutrients['FAT'] ?? 0).round(),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      throw Exception("Failed to connect to Edamam database.");
    }
  }

  // Pings the Edamam database specifically looking for a UPC barcode match.
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    if (_appId.isEmpty || _appKey.isEmpty) {
      throw Exception("API keys missing from .env file");
    }

    try {
      // The endpoint is the exact same as a text search, we just swap 'ingr=' for 'upc='
      final url = Uri.parse('https://api.edamam.com/api/food-database/v2/parser?app_id=$_appId&app_key=$_appKey&upc=$barcode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List hints = data['hints'] ?? [];
        
        // If the barcode matches something, Edamam will return it as the first item in the hints array
        if (hints.isNotEmpty) {
          final food = hints.first['food'] ?? {};
          final nutrients = food['nutrients'] ?? {};
          
          return FoodItem(
            name: food['label'] ?? 'Unknown Product',
            calories: (nutrients['ENERC_KCAL'] ?? 0).round(),
            protein: (nutrients['PROCNT'] ?? 0).round(),
            carbs: (nutrients['CHOCDF'] ?? 0).round(),
            fat: (nutrients['FAT'] ?? 0).round(),
          );
        }
      }
      return null; // Return null if the barcode isn't in their system yet
    } catch (e) {
      throw Exception("Barcode not found in database.");
    }
  }
}