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

  void sendCheckIn() {
    print("Check-in sent!");
  }

  // 🔍 SEARCH CAREGIVERS
  void searchCaregivers() async {
    setState(() => isLoading = true);

    String query = searchController.text.trim().toLowerCase();

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "caregiver")
          .get();

      caregivers = snapshot.docs
          .where((doc) {
            String username = (doc["username"] ?? "").toString().toLowerCase();
            String email = (doc["email"] ?? "").toString().toLowerCase();

            return username.contains(query) || email.contains(query);
          })
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Search error: $e");
    }

    setState(() => isLoading = false);
  }

  // 🤝 SEND CONNECTION REQUEST
  void sendRequest(String caregiverId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _connectionService.sendRequest(
      elderlyId: user.uid,
      caregiverId: caregiverId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Request sent to caregiver")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Elderly Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ❤️ STATUS BUTTON
            ElevatedButton(
              onPressed: sendCheckIn,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
              child: Text(
                "I'm OK ✅",
                style: TextStyle(fontSize: 18),
              ),
            ),

            SizedBox(height: 20),

            // 🔍 SEARCH INPUT
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Search caregiver",
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: searchCaregivers,
                ),
              ),
            ),

            SizedBox(height: 10),

            if (isLoading) CircularProgressIndicator(),

            // 📋 RESULTS LIST
            Expanded(
              child: ListView.builder(
                itemCount: caregivers.length,
                itemBuilder: (context, index) {
                  final user = caregivers[index];

                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text(user["fullName"] ?? "No Name"),
                      subtitle: Text(user["username"] ?? ""),
                      trailing: ElevatedButton(
                        onPressed: () {
                          sendRequest(user["uid"]);
                        },
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
