import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/connection_service.dart';

class CaregiverHome extends StatefulWidget {
  @override
  _CaregiverHomeState createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  final ConnectionService _connectionService = ConnectionService();

  String lastCheckIn = "No check-ins yet";

  final user = FirebaseAuth.instance.currentUser;

  // ✅ ACCEPT REQUEST
  void acceptRequest(String connectionId) async {
    await _connectionService.acceptRequest(connectionId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Request accepted")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Caregiver Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ❤️ CHECK-IN SIMULATION (you can replace later with real alerts)
            Text(
              "Last Check-In:",
              style: TextStyle(fontSize: 18),
            ),

            SizedBox(height: 10),

            Text(
              lastCheckIn,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  lastCheckIn = "Received just now ✅";
                });
              },
              child: Text("Simulate Check-In"),
            ),

            SizedBox(height: 30),

            Divider(),

            // 📩 PENDING REQUESTS
            Text(
              "Incoming Requests",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("connections")
                    .where("caregiverId", isEqualTo: user!.uid)
                    .where("status", isEqualTo: "pending")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(child: Text("No requests"));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index];
                      final connectionId = docs[index].id;

                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.person),
                          title: Text("Elderly Request"),
                          subtitle: Text("Waiting for approval"),
                          trailing: ElevatedButton(
                            onPressed: () {
                              acceptRequest(connectionId);
                            },
                            child: Text("Accept"),
                          ),
                        ),
                      );
                    },
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
