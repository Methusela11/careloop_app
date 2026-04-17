import 'package:flutter/material.dart';

class ElderlyHome extends StatelessWidget {

  void sendCheckIn() {
    print("Check-in sent!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Elderly Dashboard"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: sendCheckIn,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 30),
          ),
          child: Text(
            "I'm OK ✅",
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}