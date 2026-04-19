import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/connection_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class ElderlyHome extends StatefulWidget {
  const ElderlyHome({super.key});

  @override
  State<ElderlyHome> createState() => _ElderlyHomeState();
}

class CaregiverSearchDelegate extends SearchDelegate {
  final Function(String) onConnect;

  CaregiverSearchDelegate({
    required this.onConnect,
  });

  @override
  String get searchFieldLabel => "Search caregiver";

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = "";
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  // 🔥 REAL SEARCH FUNCTION
  Future<List<Map<String, dynamic>>> searchCaregivers(String query) async {
    query = query.toLowerCase();

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "caregiver")
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      String username = (data["username"] ?? "").toLowerCase();
      String fullName = (data["fullName"] ?? "").toLowerCase();
      String email = (data["email"] ?? "").toLowerCase();

      return username.contains(query) ||
          fullName.contains(query) ||
          email.contains(query);
    }).map((doc) {
      final data = doc.data() as Map<String, dynamic>;

      return {
        "uid": data["uid"] ?? doc.id,
        "username": data["username"] ?? "",
        "fullName": data["fullName"] ?? "",
      };
    }).toList();
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: searchCaregivers(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data!;

        if (results.isEmpty) {
          return const Center(child: Text("No caregivers found"));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final user = results[index];

            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(user["fullName"]),
              subtitle: Text("@${user["username"]}"),
              trailing: ElevatedButton(
                onPressed: () => onConnect(user["uid"]),
                child: const Text("Connect"),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text("Search by name, username or email"),
    );
  }
}

class _ElderlyHomeState extends State<ElderlyHome> {
  final ConnectionService _connectionService = ConnectionService();
  final AuthService _authService = AuthService();

  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      setState(() {
        userData = data;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void sendCheckIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot conn = await FirebaseFirestore.instance
        .collection("connections")
        .where("elderlyId", isEqualTo: user.uid)
        .where("status", isEqualTo: "accepted")
        .get();

    if (conn.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No caregiver connected ❗")),
      );
      return;
    }

    String caregiverId = conn.docs.first["caregiverId"];

    await FirebaseFirestore.instance.collection("checkins").add({
      "elderlyId": user.uid,
      "caregiverId": caregiverId,
      "status": "ok",
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Check-in sent ✅")),
    );
  }

  // 🤝 SEND REQUEST
  void sendRequest(String caregiverId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _connectionService.sendRequest(
      elderlyId: user.uid,
      caregiverId: caregiverId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Request sent successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isLoading
            ? const Text("Elderly Dashboard")
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Elderly Dashboard",
                    style: TextStyle(fontSize: 16),
                  ),
                  if (userData != null && userData!["username"] != null)
                    Text(
                      "@${userData!["username"]}",
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                ],
              ),
        actions: [
          // 🔍 SEARCH
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CaregiverSearchDelegate(
                  onConnect: sendRequest,
                ),
              );
            },
          ),

          // 👤 PROFILE - Updated to navigate to ProfileScreen
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isLoading && userData != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Welcome, ${userData!["fullName"] ?? "User"}!",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendCheckIn,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: const Text(
                "I'm OK ✅",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
