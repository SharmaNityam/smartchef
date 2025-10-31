import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIRecipeChatScreen extends StatefulWidget {
  final RecipeModel recipe;

  const AIRecipeChatScreen({
    Key? key,
    required this.recipe,
  }) : super(key: key);

  @override
  _AIRecipeChatScreenState createState() => _AIRecipeChatScreenState();
}

class _AIRecipeChatScreenState extends State<AIRecipeChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String get apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  final String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    final recipeDetails = '''
# ${widget.recipe.title}

${widget.recipe.description}

## Ingredients:
${widget.recipe.ingredients.map((ing) => "• $ing").join('\n')}

## Instructions:
${widget.recipe.instructions.asMap().entries.map((entry) => "${entry.key + 1}. ${entry.value}").join('\n')}

What would you like to modify about this recipe?
    ''';

    setState(() {
      _messages = [
        {
          'isUser': false,
          'message': recipeDetails,
        }
      ];
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message to the chat
    setState(() {
      _messages.add({
        'isUser': true,
        'message': message,
      });

      // Add a loading message
      _messages.add({
        'isUser': false,
        'message': '...',
        'isLoading': true,
      });

      _isLoading = true;
      _messageController.clear();
    });

    try {
      // Create the recipe context
      final recipeContext = '''
Recipe: ${widget.recipe.title}
Ingredients: ${widget.recipe.ingredients.join(', ')}
Instructions: ${widget.recipe.instructions.join(' ')}
      ''';

      // Create the prompt
      final prompt = '''
You are an AI chef assistant helping with recipe modifications. Here's the current recipe context:

$recipeContext

User question: $message

Provide a helpful, conversational response suggesting modifications to the recipe based on the user's request.
Keep your response friendly, specific, and actionable. Use markdown formatting for better readability.
      ''';

      // Create the payload
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

      // Send the request directly
      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('API Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Parse the response
        final data = jsonDecode(response.body);
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        print('Response received with length: ${responseText.length}');
        print(
            'Response first 100 chars: ${responseText.substring(0, responseText.length > 100 ? 100 : responseText.length)}');

        // Update the UI with the response - IMPORTANT: Replace the loading message
        setState(() {
          // Remove the loading message
          _messages.removeLast();

          // Add the actual response
          _messages.add({
            'isUser': false,
            'message': responseText,
          });

          _isLoading = false;
        });

        print('UI state updated with response');
      } else {
        // Handle API error
        print('API Error: ${response.body}');

        setState(() {
          // Remove the loading message
          _messages.removeLast();

          // Add error message
          _messages.add({
            'isUser': false,
            'message':
                'Sorry, I had trouble getting a response. Please try again.',
          });

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');

      setState(() {
        // Remove the loading message
        _messages.removeLast();

        // Add error message
        _messages.add({
          'isUser': false,
          'message': 'An error occurred. Please try again.',
        });

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Recipe Chat'),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];

                // Show loading indicator for loading messages
                if (message['isLoading'] == true) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                return _buildMessageBubble(
                  message['message'],
                  message['isUser'],
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about modifying this recipe...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isLoading,
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child: Icon(Icons.send),
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
