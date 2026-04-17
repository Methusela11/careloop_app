import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/connection_service.dart';

class ElderlyHome extends StatefulWidget {
  @override
  State<ElderlyHome> createState() => _ElderlyHomeState();
}

class _ElderlyHomeState extends State<ElderlyHome> {
  final TextEditingController searchController = TextEditingController();
  final ConnectionService _connectionService = ConnectionService();

  List<Map<String, dynamic>> caregivers = [];
  bool isLoading = false;

  void sendCheckIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // get caregiver connection
    QuerySnapshot conn = await FirebaseFirestore.instance
        .collection("connections")
        .where("elderlyId", isEqualTo: user.uid)
        .where("status", isEqualTo: "accepted")
        .get();

    if (conn.docs.isEmpty) return;

    String caregiverId = conn.docs.first["caregiverId"];

    await FirebaseFirestore.instance.collection("checkins").add({
      "elderlyId": user.uid,
      "caregiverId": caregiverId,
      "status": "ok",
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Check-in sent ✅")),
    );
  }

  // 🔍 SEARCH CAREGIVERS (FINAL VERSION)
  void searchCaregivers() async {
    setState(() => isLoading = true);

    String query = searchController.text.trim().toLowerCase();

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "caregiver")
          .get();

      caregivers = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        String username = (data["username"] ?? "").toString().toLowerCase();
        String fullName = (data["fullName"] ?? "").toString().toLowerCase();
        String email = (data["email"] ?? "").toString().toLowerCase();

        return username.contains(query) ||
            fullName.contains(query) ||
            email.contains(query);
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        return {
          "uid": data["uid"] ?? doc.id,
          "username": data["username"] ?? "",
          "fullName": data["fullName"] ?? "",
          "email": data["email"] ?? "",
        };
      }).toList();
    } catch (e) {
      print("Search error: $e");
    }

    setState(() => isLoading = false);
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
      SnackBar(content: Text("Request sent successfully")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Elderly Dashboard")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: sendCheckIn,
              child: Text("I'm OK ✅"),
            ),
            SizedBox(height: 20),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search caregiver (username / name / email)",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchCaregivers,
                ),
              ),
            ),
            SizedBox(height: 10),
            if (isLoading) CircularProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: caregivers.length,
                itemBuilder: (context, index) {
                  final user = caregivers[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text(user["fullName"]),
                      subtitle: Text("@${user["username"]}"),
                      trailing: ElevatedButton(
                        onPressed: () => sendRequest(user["uid"]),
                        child: Text("Connect"),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
