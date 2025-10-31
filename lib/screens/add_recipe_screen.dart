import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:smartchef/models/recipe_model.dart';
import 'package:smartchef/services/auth_service.dart';
import 'package:smartchef/services/recipe_service.dart';
import 'package:smartchef/services/storage_service.dart';

class AddRecipeScreen extends StatefulWidget {
  final RecipeModel? editRecipe;

  const AddRecipeScreen({
    Key? key,
    this.editRecipe,
  }) : super(key: key);

  @override
  _AddRecipeScreenState createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _ingredientController = TextEditingController();
  final _instructionController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _tagController = TextEditingController();

  File? _recipeImage;
  String? _existingImageUrl;
  List<String> _ingredients = [];
  List<String> _instructions = [];
  List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.editRecipe != null) {
      // Populate form with existing recipe data
      _titleController.text = widget.editRecipe!.title;
      _descriptionController.text = widget.editRecipe!.description;
      _prepTimeController.text = widget.editRecipe!.prepTimeMinutes.toString();
      _cookTimeController.text = widget.editRecipe!.cookTimeMinutes.toString();
      _servingsController.text = widget.editRecipe!.servings.toString();
      _caloriesController.text =
          widget.editRecipe!.nutritionInfo['calories'].toString();
      _proteinController.text =
          widget.editRecipe!.nutritionInfo['protein'].toString();
      _carbsController.text =
          widget.editRecipe!.nutritionInfo['carbs'].toString();
      _fatController.text = widget.editRecipe!.nutritionInfo['fat'].toString();

      _existingImageUrl = widget.editRecipe!.imageUrl;
      _ingredients = List.from(widget.editRecipe!.ingredients);
      _instructions = List.from(widget.editRecipe!.instructions);
      _tags = List.from(widget.editRecipe!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _ingredientController.dispose();
    _instructionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker imagePicker = ImagePicker();
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        _recipeImage = File(image.path);
      });
    }
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();

    if (ingredient.isNotEmpty) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addInstruction() {
    final instruction = _instructionController.text.trim();

    if (instruction.isNotEmpty) {
      setState(() {
        _instructions.add(instruction);
        _instructionController.clear();
      });
    }
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructions.removeAt(index);
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();

    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    if (_recipeImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a recipe image')),
      );
      return;
    }

    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }

    if (_instructions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add at least one instruction')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final recipeService = Provider.of<RecipeService>(context, listen: false);
      final storageService =
          Provider.of<StorageService>(context, listen: false);

      final user = await authService.getCurrentUserData();
      if (user == null) throw Exception('User not found');

      // Upload image if a new one was selected
      String imageUrl = _existingImageUrl ?? '';
      if (_recipeImage != null) {
        final uploadedUrl =
            await storageService.uploadRecipeImage(_recipeImage!);
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        } else {
          throw Exception('Failed to upload image');
        }
      }

      // Create nutrition info map
      final nutritionInfo = {
        'calories': int.tryParse(_caloriesController.text) ?? 0,
        'protein': _proteinController.text,
        'carbs': _carbsController.text,
        'fat': _fatController.text,
      };

      if (widget.editRecipe != null) {
        // Update existing recipe
        final updatedRecipe = RecipeModel(
          id: widget.editRecipe!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
          authorId: user.uid,
          authorName: user.displayName,
          ingredients: _ingredients,
          instructions: _instructions,
          nutritionInfo: nutritionInfo,
          prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
          cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
          tags: _tags,
          servings: int.tryParse(_servingsController.text) ?? 2,
          createdAt: widget.editRecipe!.createdAt,
          viewCount: widget.editRecipe!.viewCount,
          likeCount: widget.editRecipe!.likeCount,
        );

        final success = await recipeService.updateRecipe(updatedRecipe);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe updated successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        // Create new recipe
        final newRecipe = RecipeModel(
          id: '', // Will be set by Firestore
          title: _titleController.text,
          description: _descriptionController.text,
          imageUrl: imageUrl,
          authorId: user.uid,
          authorName: user.displayName,
          ingredients: _ingredients,
          instructions: _instructions,
          nutritionInfo: nutritionInfo,
          prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
          cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
          tags: _tags,
          servings: int.tryParse(_servingsController.text) ?? 2,
          createdAt: DateTime.now(),
        );

        final recipeId = await recipeService.addRecipe(newRecipe);

        if (recipeId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recipe added successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error saving recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editRecipe != null ? 'Edit Recipe' : 'Add Recipe'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          image: _recipeImage != null
                              ? DecorationImage(
                                  image: FileImage(_recipeImage!),
                                  fit: BoxFit.cover,
                                )
                              : _existingImageUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_existingImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: _recipeImage == null && _existingImageUrl == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 50,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Select Recipe Image',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                      ),
                    ),

                    SizedBox(height: 24),

                    // Recipe Basic Info
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Recipe Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 24),

                    // Cooking Info
                    Text(
                      'Cooking Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Cooking Info Row
                    Row(
                      children: [
                        // Prep Time
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: InputDecoration(
                              labelText: 'Prep Time (min)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Enter a number';
                              }
                              return null;
                            },
                          ),
                        ),

                        SizedBox(width: 16),

                        // Cook Time
                        Expanded(
                          child: TextFormField(
                            controller: _cookTimeController,
                            decoration: InputDecoration(
                              labelText: 'Cook Time (min)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Enter a number';
                              }
                              return null;
                            },
                          ),
                        ),

                        SizedBox(width: 16),

                        // Servings
                        Expanded(
                          child: TextFormField(
                            controller: _servingsController,
                            decoration: InputDecoration(
                              labelText: 'Servings',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Enter a number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Ingredients
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Add Ingredient
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ingredientController,
                            decoration: InputDecoration(
                              hintText: 'Add ingredient',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addIngredient(),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _addIngredient,
                          child: Text('Add'),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Ingredients List
                    if (_ingredients.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No ingredients added yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _ingredients.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.circle, size: 8),
                            title: Text(_ingredients[index]),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeIngredient(index),
                            ),
                          );
                        },
                      ),

                    SizedBox(height: 24),

                    // Instructions
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Add Instruction
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _instructionController,
                            decoration: InputDecoration(
                              hintText: 'Add instruction step',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            onSubmitted: (_) => _addInstruction(),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _addInstruction,
                          child: Text('Add'),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Instructions List
                    if (_instructions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No instructions added yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _instructions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(_instructions[index]),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeInstruction(index),
                            ),
                          );
                        },
                      ),

                    SizedBox(height: 24),

                    // Nutrition Info
                    Text(
                      'Nutrition Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Nutrition Info Row 1
                    Row(
                      children: [
                        // Calories
                        Expanded(
                          child: TextFormField(
                            controller: _caloriesController,
                            decoration: InputDecoration(
                              labelText: 'Calories',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Enter a number';
                              }
                              return null;
                            },
                          ),
                        ),

                        SizedBox(width: 16),

                        // Protein
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            decoration: InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Nutrition Info Row 2
                    Row(
                      children: [
                        // Carbs
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            decoration: InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),

                        SizedBox(width: 16),

                        // Fat
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            decoration: InputDecoration(
                              labelText: 'Fat (g)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Tags
                    Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Add Tag
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              hintText: 'Add tag (e.g., vegan, breakfast)',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _addTag,
                          child: Text('Add'),
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Tags Wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          deleteIcon: Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveRecipe,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          widget.editRecipe != null
                              ? 'Update Recipe'
                              : 'Save Recipe',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
