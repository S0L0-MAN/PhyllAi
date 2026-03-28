import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelProvider extends ChangeNotifier {
  // Default model path - ensure this file exists in your assets/models/ folder
  String _selectedModel = "assets/models/mobile_net_applerandomized.onnx";

  // Getter to access the current model path from any UI component
  String get selectedModel => _selectedModel;

  ModelProvider() {
    // Automatically load the last saved preference when the app starts
    _loadSavedModel();
  }

  /// Retrieves the stored model path from local storage
  Future<void> _loadSavedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString('selected_model');
      
      if (savedModel != null && savedModel.isNotEmpty) {
        _selectedModel = savedModel;
        notifyListeners(); // Refresh the UI with the saved model
      }
    } catch (e) {
      debugPrint("Error loading saved model preference: $e");
    }
  }

  /// Updates the active model and persists the choice to local storage
  Future<void> setModel(String modelPath) async {
    if (_selectedModel == modelPath) return; // Optimization: do nothing if same

    _selectedModel = modelPath;
    
    // Notify all listening widgets (WelcomePage, Dashboard, etc.) to rebuild
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', modelPath);
    } catch (e) {
      debugPrint("Error saving model preference: $e");
    }
  }
}