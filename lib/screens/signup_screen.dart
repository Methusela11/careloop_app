import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final fullNameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool isLoading = false;

  String role = "elderly"; // 👈 DEFAULT ROLE

  void signup() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    if (fullNameController.text.isEmpty ||
        usernameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await _authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        role: role, // ✅ NOW FROM DROPDOWN
        fullName: fullNameController.text.trim(),
        username: usernameController.text.trim().toLowerCase(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Account created successfully")),
      );

      Navigator.pushReplacementNamed(context, "/login");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup error: $e")),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [

              TextField(
                controller: fullNameController,
                decoration: InputDecoration(labelText: "Full Name"),
              ),

              TextField(
                controller: usernameController,
                decoration: InputDecoration(labelText: "Username"),
              ),

              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
              ),

              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),

              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(labelText: "Confirm Password"),
                obscureText: true,
              ),

              SizedBox(height: 15),

              // 🔥 ROLE SELECT DROPDOWN
              DropdownButton<String>(
                value: role,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: "elderly",
                    child: Text("Elderly"),
                  ),
                  DropdownMenuItem(
                    value: "caregiver",
                    child: Text("Caregiver"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    role = value!;
                  });
                },
              ),

              SizedBox(height: 20),

              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: signup,
                      child: Text("Sign Up"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}