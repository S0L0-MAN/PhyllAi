import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // 1. Added Provider
import 'package:path/path.dart' as p;    // 2. Added Path for filename parsing
import 'dashboard.dart';
import 'model_provider.dart';           // 3. Added ModelProvider import

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    setState(() => _isPressed = true);
    _controller.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    _controller.reverse();
    setState(() => _isPressed = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D986A);
    
    // 4. Listen to the ModelProvider
    final modelProvider = Provider.of<ModelProvider>(context);
    final String activeModelPath = modelProvider.selectedModel;
    final String modelName = p.basename(activeModelPath)
        .replaceAll('.onnx', '')
        .replaceAll('_', ' ')
        .toUpperCase();

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 80, color: Colors.white),
              const SizedBox(height: 25),
              Text(
                "PHYLL AI",
                style: GoogleFonts.chakraPetch(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.0,
                ),
              ),
              const Text(
                "CROP DISEASE DIAGNOSTICS",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 120),

              ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: 200,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _handleTap,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _isPressed ? Colors.transparent : Colors.white,
                      foregroundColor: _isPressed ? Colors.white : primaryColor,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "EXPLORE",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 80),
              
              // 5. DYNAMIC STATUS LABEL
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(radius: 4, backgroundColor: Colors.lightGreenAccent),
                  const SizedBox(width: 10),
                  Text(
                    "$modelName READY",
                    style: const TextStyle(
                      color: Colors.white54, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}