import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/recipe_model.dart';

class GeminiService {
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  final String visionBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  // Generate recipe from ingredients
  Future<Map<String, dynamic>> generateRecipeFromIngredients(
      List<String> ingredients) async {
    try {
      final prompt = '''
Create a detailed recipe using some or all of these ingredients: ${ingredients.join(', ')}.
IMPORTANT: Return ONLY a raw JSON object. DO NOT use markdown formatting or code blocks (```).
The response should be a valid JSON object with this structure:
{
  "title": "Recipe Name",
  "description": "Brief description",
  "ingredients": ["ingredient 1", "ingredient 2"],
  "instructions": ["step 1", "step 2"],
  "nutritionInfo": {
    "calories": 123,
    "protein": "10 g",
    "carbs": "20 g",
    "fat": "5 g"
  },
  "prepTimeMinutes": 15,
  "cookTimeMinutes": 25,
  "tags": ["tag1", "tag2"],
  "servings": 4
}
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
          "responseMimeType": 'application/json',
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('API Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        print('Raw Gemini response: $responseText');

        // Try to parse the JSON directly
        try {
          final recipeData = jsonDecode(responseText);
          return recipeData;
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');

          // Clean the response and try again
          final cleanedResponse = _cleanJsonResponse(responseText);

          try {
            return jsonDecode(cleanedResponse);
          } catch (e) {
            print('Cleaned JSON parsing error: $e');
            return _createFallbackRecipe(ingredients[0]);
          }
        }
      } else {
        print('API Error: ${response.body}');
        return _createFallbackRecipe(ingredients[0]);
      }
    } catch (e) {
      print('Error generating recipe: $e');
      return _createFallbackRecipe(ingredients[0]);
    }
  }

  // Generate image description for recipe
  Future<String> generateImageDescription(
      String recipeTitle, List<String> ingredients) async {
    try {
      final prompt = '''
Generate a short, specific description for a food photography image of this recipe: ${recipeTitle}
The recipe uses these ingredients: ${ingredients.join(', ')}
Keep the description under 10 words and focus on the main dish. Do NOT return any explanation, just the description.
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];
        print('Image description response: $responseText');
        return responseText.trim();
      } else {
        return recipeTitle.toLowerCase();
      }
    } catch (e) {
      print('Error generating image description: $e');
      return recipeTitle.toLowerCase();
    }
  }

  // Get recipe chat response
  Future<String> getRecipeChatResponse(
      String recipeContext, String userMessage) async {
    try {
      final prompt = '''
You are an AI chef assistant helping with recipe modifications. Here's the current recipe context:

$recipeContext

User question: $userMessage

Provide a helpful, conversational response suggesting modifications to the recipe based on the user's request.
Keep your response friendly, specific, and actionable. Use markdown formatting for better readability.
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('Chat API Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        print('Chat response received with length: ${responseText.length}');
        print(
            'First 100 chars of response: ${responseText.substring(0, min(100, responseText.length))}');

        return responseText;
      } else {
        print('Chat API Error: ${response.body}');
        return "I'm having trouble processing your request right now. Could you please try again?";
      }
    } catch (e) {
      print('Error getting recipe chat response: $e');
      return "I'm having trouble processing your request right now. Could you please try again?";
    }
  }

  // Helper function for min
  int min(int a, int b) {
    return a < b ? a : b;
  }

  // Generate updated recipe from chat
  Future<Map<String, dynamic>> generateUpdatedRecipeFromChat(
      RecipeModel originalRecipe, String conversation) async {
    try {
      final prompt = '''
Based on the following conversation about modifying a recipe, generate an updated version of the recipe.
Return ONLY a JSON object with the modified recipe details, no extra text.

Original Recipe:
Title: ${originalRecipe.title}
Description: ${originalRecipe.description}
Ingredients: ${originalRecipe.ingredients.join(', ')}
Instructions: ${originalRecipe.instructions.join(' ')}

Conversation:
$conversation

Create a JSON object with these exact fields:
{
  "title": "Updated Recipe Title",
  "description": "Updated description",
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "instructions": ["step 1", "step 2", ...],
  "nutritionInfo": {
    "calories": X,
    "protein": "X g",
    "carbs": "X g",
    "fat": "X g"
  },
  "prepTimeMinutes": X,
  "cookTimeMinutes": X,
  "tags": ["tag1", "tag2", ...],
  "servings": X
}
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
          "responseMimeType": 'application/json',
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        try {
          return jsonDecode(responseText);
        } catch (jsonError) {
          print('JSON parsing error in updated recipe: $jsonError');

          // Clean the response and try again
          final cleanedResponse = _cleanJsonResponse(responseText);

          try {
            return jsonDecode(cleanedResponse);
          } catch (e) {
            print('Cleaned JSON parsing error in updated recipe: $e');
            return {
              'title': originalRecipe.title,
              'description': originalRecipe.description,
              'ingredients': originalRecipe.ingredients,
              'instructions': originalRecipe.instructions,
              'nutritionInfo': originalRecipe.nutritionInfo,
              'prepTimeMinutes': originalRecipe.prepTimeMinutes,
              'cookTimeMinutes': originalRecipe.cookTimeMinutes,
              'tags': originalRecipe.tags,
              'servings': originalRecipe.servings,
            };
          }
        }
      } else {
        return {
          'title': originalRecipe.title,
          'description': originalRecipe.description,
          'ingredients': originalRecipe.ingredients,
          'instructions': originalRecipe.instructions,
          'nutritionInfo': originalRecipe.nutritionInfo,
          'prepTimeMinutes': originalRecipe.prepTimeMinutes,
          'cookTimeMinutes': originalRecipe.cookTimeMinutes,
          'tags': originalRecipe.tags,
          'servings': originalRecipe.servings,
        };
      }
    } catch (e) {
      print('Error generating updated recipe: $e');
      return {
        'title': originalRecipe.title,
        'description': originalRecipe.description,
        'ingredients': originalRecipe.ingredients,
        'instructions': originalRecipe.instructions,
        'nutritionInfo': originalRecipe.nutritionInfo,
        'prepTimeMinutes': originalRecipe.prepTimeMinutes,
        'cookTimeMinutes': originalRecipe.cookTimeMinutes,
        'tags': originalRecipe.tags,
        'servings': originalRecipe.servings,
      };
    }
  }

  // Get similar ingredients
  Future<List<String>> getSimilarIngredients(String ingredient) async {
    try {
      final prompt = '''
Give me 5 ingredients that are similar to or can substitute for "${ingredient}".
Return ONLY a JSON array of strings. Example: ["ingredient1", "ingredient2", "ingredient3", "ingredient4", "ingredient5"]
Include the original ingredient in the list.
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
          "responseMimeType": 'application/json',
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        try {
          final List<dynamic> ingredients = jsonDecode(responseText);
          return ingredients.map((e) => e.toString()).toList();
        } catch (e) {
          print('Error parsing similar ingredients: $e');
          return [ingredient];
        }
      } else {
        return [ingredient];
      }
    } catch (e) {
      print('Error getting similar ingredients: $e');
      return [ingredient];
    }
  }

  // Identify food from image
  Future<Map<String, dynamic>> identifyFoodFromImage(String imageUrl) async {
    try {
      // First download the image
      final imageResponse = await http.get(Uri.parse(imageUrl));
      final base64Image = base64Encode(imageResponse.bodyBytes);

      final prompt = '''
Identify the food or dish in this image. 
Return ONLY a JSON object with:
1. "name": The name of the dish
2. "ingredients": An array of likely ingredients (up to 10)
3. "cuisine": The likely cuisine type
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image}
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4,
          "topK": 32,
          "topP": 0.95,
          "maxOutputTokens": 1024,
          "responseMimeType": 'application/json',
        }
      };

      final response = await http.post(
        Uri.parse('$visionBaseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        try {
          return jsonDecode(responseText);
        } catch (e) {
          print('Error parsing food identification: $e');
          return {
            'name': 'Unknown Food',
            'ingredients': ['ingredient1', 'ingredient2'],
            'cuisine': 'Unknown'
          };
        }
      } else {
        return {
          'name': 'Unknown Food',
          'ingredients': ['ingredient1', 'ingredient2'],
          'cuisine': 'Unknown'
        };
      }
    } catch (e) {
      print('Error identifying food from image: $e');
      return {
        'name': 'Unknown Food',
        'ingredients': ['ingredient1', 'ingredient2'],
        'cuisine': 'Unknown'
      };
    }
  }

  // Get recipe details from text
  Future<Map<String, dynamic>> getRecipeDetailsFromText(
      String recipeText) async {
    try {
      final prompt = '''
Parse the following recipe text and convert it to a structured format.
Return ONLY a JSON object with:
{
  "title": "Recipe Name",
  "description": "Brief description",
  "ingredients": ["ingredient 1", "ingredient 2", ...],
  "instructions": ["step 1", "step 2", ...],
  "nutritionInfo": {
    "calories": X,
    "protein": "X g",
    "carbs": "X g",
    "fat": "X g"
  },
  "prepTimeMinutes": X,
  "cookTimeMinutes": X,
  "tags": ["tag1", "tag2", ...],
  "servings": X
}

Recipe text: $recipeText
      ''';

      final payload = {
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
          "responseMimeType": 'application/json',
        }
      };

      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        try {
          return jsonDecode(responseText);
        } catch (e) {
          // Return fallback
          return {
            'title': 'Recipe',
            'description': 'A recipe based on the provided text.',
            'ingredients': ['Ingredient 1', 'Ingredient 2'],
            'instructions': ['Step 1', 'Step 2'],
            'nutritionInfo': {
              'calories': 0,
              'protein': '0 g',
              'carbs': '0 g',
              'fat': '0 g'
            },
            'prepTimeMinutes': 10,
            'cookTimeMinutes': 20,
            'tags': ['quick', 'easy'],
            'servings': 2
          };
        }
      } else {
        return {
          'title': 'Recipe',
          'description': 'A recipe based on the provided text.',
          'ingredients': ['Ingredient 1', 'Ingredient 2'],
          'instructions': ['Step 1', 'Step 2'],
          'nutritionInfo': {
            'calories': 0,
            'protein': '0 g',
            'carbs': '0 g',
            'fat': '0 g'
          },
          'prepTimeMinutes': 10,
          'cookTimeMinutes': 20,
          'tags': ['quick', 'easy'],
          'servings': 2
        };
      }
    } catch (e) {
      print('Error getting recipe details from text: $e');
      return {
        'title': 'Recipe',
        'description': 'A recipe based on the provided text.',
        'ingredients': ['Ingredient 1', 'Ingredient 2'],
        'instructions': ['Step 1', 'Step 2'],
        'nutritionInfo': {
          'calories': 0,
          'protein': '0 g',
          'carbs': '0 g',
          'fat': '0 g'
        },
        'prepTimeMinutes': 10,
        'cookTimeMinutes': 20,
        'tags': ['quick', 'easy'],
        'servings': 2
      };
    }
  }

  // Helper method for extensive JSON cleaning
  String _cleanJsonResponse(String response) {
    // Remove any markdown code block markers
    response = response.replaceAll(
        RegExp(r'```json|```javascript|```js|```', multiLine: true), '');

    // Handle potential line breaks and ensure proper JSON formatting
    response = response.trim();

    // Remove any explanatory text before or after JSON
    final jsonPattern = RegExp(r'(\{[\s\S]*\})');
    final match = jsonPattern.firstMatch(response);
    if (match != null) {
      response = match.group(1)!;
    }

    // Fix common formatting issues
    response = response
        .replaceAll(RegExp(r'[\r\n]+'), '\n') // Normalize line breaks
        .replaceAll(RegExp(r',\s*\}'), '}') // Remove trailing commas
        .replaceAll(RegExp(r',\s*\]'), ']') // Remove trailing commas in arrays
        .replaceAll(
            RegExp(r'"\s*:\s*"'), '":"') // Normalize string key-value spacing
        .replaceAll(RegExp(r'"\s*:\s*'), '":') // Normalize key-value spacing
        .replaceAll(RegExp(r'\s*:\s*"'), ':"') // Normalize key-value spacing
        .replaceAll(RegExp(r'[\u2018\u2019]'), "'") // Replace smart quotes
        .replaceAll(
            RegExp(r'[\u201C\u201D]'), '"'); // Replace smart double quotes

    return response;
  }

  // Helper method for creating fallback recipes
  Map<String, dynamic> _createFallbackRecipe(String mainIngredient) {
    return {
      'title': 'Simple $mainIngredient Recipe',
      'description': 'A simple recipe featuring $mainIngredient.',
      'ingredients': [
        mainIngredient,
        'Salt and pepper to taste',
        'Olive oil',
        'Garlic (optional)',
        'Herbs of your choice'
      ],
      'instructions': [
        'Prepare $mainIngredient by washing and cutting as needed.',
        'Heat olive oil in a pan over medium heat.',
        'Add $mainIngredient and cook until done.',
        'Season with salt, pepper, and herbs.',
        'Serve and enjoy!'
      ],
      'nutritionInfo': {
        'calories': 200,
        'protein': '5 g',
        'carbs': '10 g',
        'fat': '8 g'
      },
      'prepTimeMinutes': 10,
      'cookTimeMinutes': 20,
      'tags': ['quick', 'easy', 'simple'],
      'servings': 2
    };
  }
}
