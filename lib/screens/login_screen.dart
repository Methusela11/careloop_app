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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 1, 133, 29),
        ),
        child: Stack(
          children: [
           
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 246, 139, 0),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // 🔶 Bottom yellow accent
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 246, 139, 0),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: Container(
                  // Removed Transform.rotate
                  width: 340,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Skip
                      // Align(
                      //   alignment: Alignment.topRight,
                      //   child: Text(
                      //     "Skip",
                      //     style: TextStyle(
                      //       color: Colors.grey.shade600,
                      //       fontWeight: FontWeight.w500,
                      //     ),
                      //   ),
                      // ),

                      const SizedBox(height: 10),

                      // 🔹 Logo circle
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 252, 252, 252),
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/logo/careloop-t.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      const Center(
                        child: Text(
                          "Welcome Back!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // 🔹 Email/Username
                      TextField(
                        controller: inputController,
                        decoration: InputDecoration(
                          labelText: "Email Address",
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF0F3D2E)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // 🔹 Password
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF0F3D2E)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // // 🔹 Remember + Forgot
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     Row(
                      //       children: [
                      //         Checkbox(
                      //           value: false,
                      //           onChanged: (v) {},
                      //           activeColor: const Color(0xFF0F3D2E),
                      //         ),
                      //         const Text("Remember me"),
                      //       ],
                      //     ),
                      //     TextButton(
                      //       onPressed: () {},
                      //       child: const Text(
                      //         "Forgot Password?",
                      //         style: TextStyle(color: Colors.grey),
                      //       ),
                      //     )
                      //   ],
                      // ),

                      const SizedBox(height: 10),

                      // 🔹 Login Button (keeps your logic)
                      SizedBox(
                        width: double.infinity,
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F3D2E),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "LOGIN",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                      ),

                      const SizedBox(height: 15),

                      // 🔹 Sign up
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, "/signup");
                          },
                          child: const Text(
                            "Don’t have an account? SIGN UP",
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
