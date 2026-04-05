import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ===========================================================================
// 1. DATA MODEL (Restored from your original file!)
// ===========================================================================
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

// ===========================================================================
// 2. EDAMAM API ENGINE
// ===========================================================================
class FoodService {
  final String _baseUrl = 'https://api.edamam.com/api/food-database/v2/parser';
  
  // Grabs your keys safely from the .env file
  final String _appId = dotenv.env['EDAMAM_APP_ID'] ?? '';
  final String _appKey = dotenv.env['EDAMAM_APP_KEY'] ?? '';

  // --- Search by Name (Text Search) ---
// --- Search by Name (Text Search) ---
  Future<List<FoodItem>> searchFood(String query) async {
    try {
      final url = Uri.parse('$_baseUrl?app_id=$_appId&app_key=$_appKey&ingr=${Uri.encodeComponent(query)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List hints = data['hints'] ?? [];
        
        return hints.take(15).map((hint) {
          final food = hint['food'];
          final nutrients = food['nutrients'] ?? {};
          return FoodItem(
            name: food['label'] ?? 'Unknown Food',
            calories: (nutrients['ENERC_KCAL'] ?? 0).round(),
            protein: (nutrients['PROCNT'] ?? 0).round(),
            carbs: (nutrients['CHOCDF'] ?? 0).round(),
            fat: (nutrients['FAT'] ?? 0).round(),
          );
        }).toList();
      } else {
        // NEW: Force the app to show the actual server error!
        throw Exception("Edamam Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      print("Error searching food: $e");
      // Pass the real error up to the UI instead of a generic message
      throw Exception(e.toString()); 
    }
  }

  // --- Search by Barcode ---
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl?app_id=$_appId&app_key=$_appKey&upc=$barcode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List hints = data['hints'] ?? [];
        
        if (hints.isNotEmpty) {
          final food = hints.first['food'];
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
      return null; 
    } catch (e) {
      print("Error scanning barcode: $e");
      throw Exception("Could not find barcode. Try manual entry.");
    }
  }
}