import 'dart:convert';
import 'package:http/http.dart' as http;

// DATA MODEL 
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

// SPOONACULAR API ENGINE
class FoodService {
  // PASTE YOUR SPOONACULAR API KEY RIGHT HERE:
  final String _apiKey = '45e4398a5d3e44649f3a2213448b5735';

  // --- Search by Name (Text Search) ---
  Future<List<FoodItem>> searchFood(String query) async {
    try {
      final url = Uri.parse('https://api.spoonacular.com/recipes/complexSearch?query=${Uri.encodeComponent(query)}&addRecipeNutrition=true&number=15&apiKey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        
        return results.map((item) {
          final nutrition = item['nutrition'] ?? {};
          final nutrients = nutrition['nutrients'] as List? ?? [];
          
          // Safely grab the exact macro we need from Spoonacular's array
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

  // --- Search by Barcode ---
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://api.spoonacular.com/food/products/upc/$barcode?apiKey=$_apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final nutrition = data['nutrition'] ?? {};
        
        // Spoonacular barcode returns strings like "4g" for macros, so we strip the 'g'
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