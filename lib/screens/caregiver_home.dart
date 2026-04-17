import 'package:flutter/material.dart';

class CaregiverHome extends StatefulWidget {
  @override
  _CaregiverHomeState createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {

  String lastCheckIn = "No check-ins yet";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Caregiver Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [

            Text(
              "Last Check-In:",
              style: TextStyle(fontSize: 18),
            ),

            SizedBox(height: 10),

            Text(
              lastCheckIn,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  lastCheckIn = "Received just now ✅";
                });
              },
              child: Text("Simulate Check-In"),
            )
          ],
        ),
      ),
    );
  }
}