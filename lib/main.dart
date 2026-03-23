import 'package:flutter/material.dart';
import 'welcome.dart'; // Make sure to import your welcome file

void main() {
  runApp(const PhyllAI());
}

class PhyllAI extends StatelessWidget {
  const PhyllAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phyll AI',
      theme: ThemeData(useMaterial3: true),
      // Tell the app to start with the WelcomePage
      home: const WelcomePage(), 
    );
  }
}