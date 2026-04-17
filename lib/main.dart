import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/elderly_home.dart';
import 'screens/caregiver_home.dart';
import 'screens/splash_screen.dart';

void main() async {
  // ✅ Required for Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp();

  runApp(CareLoopApp());
}

class CareLoopApp extends StatelessWidget {
  const CareLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CareLoop',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      initialRoute: "/",
      routes: {
        "/": (context) => SplashScreen(),
        "/login": (context) => LoginScreen(),
        "/signup": (context) => SignupScreen(),
        "/elderlyHome": (context) => ElderlyHome(),
        "/caregiverHome": (context) => CaregiverHome(),
        
      },
    );
  }
}