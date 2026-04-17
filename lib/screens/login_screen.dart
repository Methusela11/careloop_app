import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final inputController = TextEditingController(); // email OR username
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isLoading = false;

  void login() async {
    setState(() {
      isLoading = true;
    });

    try {
      String input = inputController.text.trim().toLowerCase();
      String password = passwordController.text.trim();

      // 🔥 STEP 1: LOGIN (email OR username)
      await _authService.loginWithEmailOrUsername(
        input: input,
        password: password,
      );

      // 🔥 STEP 2: GET USER
      final user = _authService.getCurrentUser();
      final userData = await _authService.getUserData(user!.uid);

      String role = userData?["role"] ?? "pending";

      // 🔥 STEP 3: ROUTE BY ROLE
      if (role == "caregiver") {
        Navigator.pushReplacementNamed(context, "/caregiverHome");
      } else if (role == "elderly") {
        Navigator.pushReplacementNamed(context, "/elderlyHome");
      } else {
        Navigator.pushReplacementNamed(context, "/roleSelection");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed: $e")),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("CareLoop Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: inputController,
              decoration: InputDecoration(
                labelText: "Email or Username",
              ),
            ),

            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),

            SizedBox(height: 20),

            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    child: Text("Login"),
                  ),

            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, "/signup");
              },
              child: Text("Create account"),
            )
          ],
        ),
      ),
    );
  }
}