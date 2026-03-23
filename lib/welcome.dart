import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false; // Track if the button is currently being clicked

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
    setState(() => _isPressed = true); // Change style to Outline
    _controller.forward();
    
    await Future.delayed(const Duration(milliseconds: 200));
    
    _controller.reverse();
    setState(() => _isPressed = false); // Reset style

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Transitioning to Dashboard...")),
    );

    // Navigation logic will go here:
    // Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardPage()));
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0D986A);

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

              // THE DYNAMIC BUTTON
              ScaleTransition(
                scale: _scaleAnimation,
                child: SizedBox(
                  width: 200,
                  height: 55,
                  child: OutlinedButton(
                    onPressed: _handleTap,
                    style: OutlinedButton.styleFrom(
                      // Logic: If pressed, background is clear. If not, background is white.
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
              
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Colors.lightGreenAccent),
                  SizedBox(width: 10),
                  Text(
                    "DINOv3 ENGINE READY",
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
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