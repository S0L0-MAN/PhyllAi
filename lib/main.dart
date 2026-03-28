import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'welcome.dart';
import 'model_provider.dart'; // Import the provider we created

void main() async {
  // Ensure Flutter bindings are initialized before calling SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ModelProvider(),
      child: const PhyllAI(),
    ),
  );
}

class PhyllAI extends StatelessWidget {
  const PhyllAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phyll AI',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0D986A),
      ),
      // The app starts with WelcomePage, but now has access to ModelProvider
      home: const WelcomePage(), 
    );
  }
}