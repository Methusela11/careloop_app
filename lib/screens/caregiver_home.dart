import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../services/connection_service.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});

  @override
  _CaregiverHomeState createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome>
    with SingleTickerProviderStateMixin {
  final ConnectionService _connectionService = ConnectionService();
  final AuthService _authService = AuthService();
  final user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? userData;
  late TabController _tabController;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    if (user != null) {
      try {
        final data = await _authService.getUserData(user!.uid);
        setState(() {
          userData = data;
          isLoading = false;
        });
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading user data: $e")),
          );
        }
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> acceptRequest(String connectionId) async {
    try {
      await _connectionService.acceptRequest(connectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request accepted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error accepting request: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> rejectRequest(String connectionId) async {
    try {
      await _connectionService.rejectRequest(connectionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request rejected"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error rejecting request: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> sendAlert(String elderlyId, String elderlyName) async {
    TextEditingController messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Alert"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Send alert to $elderlyName"),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                hintText: "Alert message (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection("alerts").add({
                  "elderlyId": elderlyId,
                  "caregiverId": user!.uid,
                  "message": messageController.text.isEmpty
                      ? "Please check in with your caregiver"
                      : messageController.text,
                  "timestamp": FieldValue.serverTimestamp(),
                  "isRead": false,
                  "type": "alert",
                  "senderName": userData?["fullName"] ?? "Caregiver",
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Alert sent successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error sending alert: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Send Alert"),
          ),
        ],
      ),
    );
  }

  Future<void> sendWellnessReminder(
      String elderlyId, String elderlyName) async {
    try {
      await FirebaseFirestore.instance.collection("reminders").add({
        "elderlyId": elderlyId,
        "caregiverId": user!.uid,
        "message": "Time for your wellness check! How are you feeling today?",
        "timestamp": FieldValue.serverTimestamp(),
        "isCompleted": false,
        "type": "wellness",
        "caregiverName": userData?["fullName"] ?? "Caregiver",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Wellness reminder sent to $elderlyName"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending reminder: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> sendMedicationReminder(
      String elderlyId, String elderlyName) async {
    try {
      await FirebaseFirestore.instance.collection("reminders").add({
        "elderlyId": elderlyId,
        "caregiverId": user!.uid,
        "message": "Don't forget to take your medication! 💊",
        "timestamp": FieldValue.serverTimestamp(),
        "isCompleted": false,
        "type": "medication",
        "caregiverName": userData?["fullName"] ?? "Caregiver",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Medication reminder sent to $elderlyName"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending reminder: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void viewHealthData(String elderlyId, String elderlyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElderlyHealthDataScreen(
          elderlyId: elderlyId,
          elderlyName: elderlyName,
        ),
      ),
    );
  }

  void startVideoCall(String elderlyId, String elderlyName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Video call with $elderlyName - Coming soon!"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void sendMessage(String elderlyId, String elderlyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          elderlyId: elderlyId,
          elderlyName: elderlyName,
          caregiverId: user!.uid,
        ),
      ),
    );
  }

  void viewDailyReport(String elderlyId, String elderlyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyReportScreen(
          elderlyId: elderlyId,
          elderlyName: elderlyName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Caregiver Dashboard",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (userData != null && userData!["username"] != null)
              Text(
                "@${userData!["username"]}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserData());
            },
            tooltip: "Profile",
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person_add), text: "Requests"),
            Tab(icon: Icon(Icons.people), text: "My Elders"),
            Tab(icon: Icon(Icons.favorite), text: "Check-ins"),
            Tab(icon: Icon(Icons.notifications_active), text: "Alerts"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildMyEldersTab(),
          _buildCheckInsTab(),
          _buildAlertsTab(),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("connections")
          .where("caregiverId", isEqualTo: user!.uid)
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}"),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_disabled, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No pending requests"),
                SizedBox(height: 8),
                Text(
                  "When elderly users request to connect, they'll appear here",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final connectionId = docs[index].id;
            final elderlyId = data["elderlyId"];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(elderlyId)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    child: ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text("Loading..."),
                    ),
                  );
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (userData["fullName"]?[0] ?? "U").toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    title: Text(
                      userData["fullName"] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text("@${userData["username"] ?? "unknown"}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => rejectRequest(connectionId),
                          tooltip: "Reject",
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => acceptRequest(connectionId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Accept"),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMyEldersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("connections")
          .where("caregiverId", isEqualTo: user!.uid)
          .where("status", isEqualTo: "accepted")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}"),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No connected elders yet"),
                SizedBox(height: 8),
                Text(
                  "When elderly users connect, they'll appear here",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final elderlyId = data["elderlyId"];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(elderlyId)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    child: ListTile(title: Text("Loading...")),
                  );
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>;
                final elderlyName = userData["fullName"] ?? "Unknown";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        (elderlyName[0]).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    title: Text(
                      elderlyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text("@${userData["username"] ?? "unknown"}"),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        sendMessage(elderlyId, elderlyName),
                                    icon: const Icon(Icons.message),
                                    label: const Text("Message"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        startVideoCall(elderlyId, elderlyName),
                                    icon: const Icon(Icons.videocam),
                                    label: const Text("Video Call"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => sendWellnessReminder(
                                        elderlyId, elderlyName),
                                    icon: const Icon(Icons.health_and_safety),
                                    label: const Text("Wellness"),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => sendMedicationReminder(
                                        elderlyId, elderlyName),
                                    icon: const Icon(Icons.medication),
                                    label: const Text("Medication"),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        sendAlert(elderlyId, elderlyName),
                                    icon: const Icon(Icons.warning,
                                        color: Colors.orange),
                                    label: const Text("Send Alert"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        viewHealthData(elderlyId, elderlyName),
                                    icon: const Icon(Icons.analytics),
                                    label: const Text("Health Data"),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    viewDailyReport(elderlyId, elderlyName),
                                icon: const Icon(Icons.report),
                                label: const Text("Daily Report"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCheckInsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("checkins")
          .where("caregiverId", isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}"),
                const SizedBox(height: 8),
                const Text(
                  "Please check your internet connection",
                  style: TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Create a copy of docs and sort
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

        // Sort manually
        docs.sort((a, b) {
          final aTimestamp = a["timestamp"] as Timestamp?;
          final bTimestamp = b["timestamp"] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.toDate().compareTo(aTimestamp.toDate());
        });

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No check-ins yet"),
                SizedBox(height: 8),
                Text(
                  "When elderly users check in, they'll appear here",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final elderlyId = data["elderlyId"];
            final timestamp = data["timestamp"] as Timestamp?;
            final status = data["status"] ?? "ok";

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(elderlyId)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    child: ListTile(title: Text("Loading...")),
                  );
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>;
                final checkInTime = timestamp != null
                    ? DateFormat('MMM d, yyyy • h:mm a')
                        .format(timestamp.toDate())
                    : "Just now";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: status == "ok"
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      child: Icon(
                        status == "ok" ? Icons.check_circle : Icons.warning,
                        color: status == "ok" ? Colors.green : Colors.red,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      userData["fullName"] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("@${userData["username"] ?? "unknown"}"),
                        const SizedBox(height: 4),
                        Text(
                          checkInTime,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: status == "ok"
                        ? Chip(
                            label: const Text("OK",
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                          )
                        : Chip(
                            label: const Text("NEEDS ATTENTION",
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red,
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("alerts")
          .where("caregiverId", isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}"),
                const SizedBox(height: 8),
                const Text(
                  "Please check your internet connection",
                  style: TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Create a copy of docs and sort
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

        // Sort manually
        docs.sort((a, b) {
          final aTimestamp = a["timestamp"] as Timestamp?;
          final bTimestamp = b["timestamp"] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.toDate().compareTo(aTimestamp.toDate());
        });

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No alerts"),
                SizedBox(height: 8),
                Text(
                  "Alerts from elderly users will appear here",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final elderlyId = data["elderlyId"];
            final timestamp = data["timestamp"] as Timestamp?;
            final message = data["message"] ?? "";
            final isRead = data["isRead"] ?? false;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(elderlyId)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Card(
                    child: ListTile(title: Text("Loading...")),
                  );
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>;
                final alertTime = timestamp != null
                    ? DateFormat('MMM d, yyyy • h:mm a')
                        .format(timestamp.toDate())
                    : "Just now";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isRead ? null : Colors.red.shade50,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.red.shade100,
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      userData["fullName"] ?? "Unknown",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message, style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          alertTime,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? IconButton(
                            icon: const Icon(Icons.mark_email_read,
                                color: Colors.red),
                            onPressed: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection("alerts")
                                    .doc(docs[index].id)
                                    .update({"isRead": true});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Alert marked as read"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          )
                        : const Icon(Icons.done_all, color: Colors.green),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Supporting screens remain the same...
class ElderlyHealthDataScreen extends StatelessWidget {
  final String elderlyId;
  final String elderlyName;

  const ElderlyHealthDataScreen({
    Key? key,
    required this.elderlyId,
    required this.elderlyName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Health Data - $elderlyName"),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              "Health data tracking coming soon!",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "This feature will include vital signs, medication tracking, and more.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  final String elderlyId;
  final String elderlyName;
  final String caregiverId;

  const ChatScreen({
    Key? key,
    required this.elderlyId,
    required this.elderlyName,
    required this.caregiverId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat with $elderlyName"),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              "Chat functionality coming soon!",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Real-time messaging will be available here.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyReportScreen extends StatelessWidget {
  final String elderlyId;
  final String elderlyName;

  const DailyReportScreen({
    Key? key,
    required this.elderlyId,
    required this.elderlyName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Daily Report - $elderlyName"),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              "Daily report generation coming soon!",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "Reports will include check-ins, alerts, and reminders.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
