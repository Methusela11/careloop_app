import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ SIGN UP (stores full user profile)
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
    required String username,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      await _firestore.collection("users").doc(uid).set({
        "uid": uid,
        "fullName": fullName.trim(),
        "username": username.trim().toLowerCase(),
        "email": email.trim(),
        "role": role,
        "createdAt": FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ✅ LOGIN (EMAIL OR USERNAME SUPPORT)
  Future<UserCredential> loginWithEmailOrUsername({
    required String input,
    required String password,
  }) async {
    try {
      String email = input.trim().toLowerCase();

      // If NOT email → treat as username
      if (!input.contains("@")) {
        QuerySnapshot result = await _firestore
            .collection("users")
            .where("username", isEqualTo: input.toLowerCase())
            .limit(1)
            .get();

        if (result.docs.isEmpty) {
          throw Exception("Username not found");
        }

        email = result.docs.first["email"];
      }

      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // ✅ GET USER DATA (ROLE + PROFILE)
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection("users").doc(uid).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception("Failed to fetch user data");
    }
  }

  // ✅ CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ✅ LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}
