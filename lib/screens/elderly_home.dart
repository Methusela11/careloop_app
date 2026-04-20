import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/connection_service.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/alert_service.dart';
import '../services/message_service.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'alerts_screen.dart';

class ElderlyHome extends StatefulWidget {
  const ElderlyHome({super.key});

  @override
  State<ElderlyHome> createState() => _ElderlyHomeState();
}

class CaregiverSearchDelegate extends SearchDelegate {
  final Function(String) onConnect;
  final String currentUserId;

  CaregiverSearchDelegate({
    required this.onConnect,
    required this.currentUserId,
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

  Future<List<Map<String, dynamic>>> searchCaregivers(String query) async {
    query = query.toLowerCase();

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "caregiver")
        .get();

    // Get existing connections
    final existingConnections = await FirebaseFirestore.instance
        .collection("connections")
        .where("elderlyId", isEqualTo: currentUserId)
        .get();

    final connectedIds = existingConnections.docs
        .map((doc) => doc['caregiverId'] as String)
        .toSet();
    final pendingIds = existingConnections.docs
        .where((doc) => doc['status'] == 'pending')
        .map((doc) => doc['caregiverId'] as String)
        .toSet();

    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final caregiverId = data["uid"] ?? doc.id;

      // Skip already connected or pending caregivers
      if (connectedIds.contains(caregiverId) ||
          pendingIds.contains(caregiverId)) {
        return false;
      }

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
        "profileImageUrl": data["profileImageUrl"] ?? "",
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

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user["profileImageUrl"].isNotEmpty
                      ? NetworkImage(user["profileImageUrl"])
                      : null,
                  child: user["profileImageUrl"].isEmpty
                      ? Text(user["fullName"][0].toUpperCase())
                      : null,
                ),
                title: Text(user["fullName"]),
                subtitle: Text("@${user["username"]}"),
                trailing: ElevatedButton(
                  onPressed: () {
                    close(context, null);
                    onConnect(user["uid"]);
                  },
                  child: const Text("Connect"),
                ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Search by name, username or email"),
          SizedBox(height: 8),
          Text("Find caregivers to connect with",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ElderlyHomeState extends State<ElderlyHome> {
  final ConnectionService _connectionService = ConnectionService();
  final AuthService _authService = AuthService();
  final CheckinService _checkinService = CheckinService();
  final AlertService _alertService = AlertService();
  final MessageService _messageService = MessageService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _selectedIndex = 0;
  int _unreadMessages = 0;
  int _unreadAlerts = 0;
  String? connectedCaregiverId;
  Map<String, dynamic>? connectedCaregiver;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadConnectedCaregiver();
    _loadUnreadCounts();
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

  Future<void> _loadConnectedCaregiver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final connections = await FirebaseFirestore.instance
        .collection("connections")
        .where("elderlyId", isEqualTo: user.uid)
        .where("status", isEqualTo: "accepted")
        .limit(1)
        .get();

    if (connections.docs.isNotEmpty) {
      final caregiverId = connections.docs.first["caregiverId"];
      setState(() {
        connectedCaregiverId = caregiverId;
      });

      // Load caregiver data
      final caregiverDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(caregiverId)
          .get();

      if (caregiverDoc.exists) {
        setState(() {
          connectedCaregiver = caregiverDoc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  void _loadUnreadCounts() {
    _messageService.getUnreadMessagesCount().listen((count) {
      if (mounted) {
        setState(() {
          _unreadMessages = count;
        });
      }
    });

    _alertService.getUnreadAlertsCount().listen((count) {
      if (mounted) {
        setState(() {
          _unreadAlerts = count;
        });
      }
    });
  }

  void sendCheckIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (connectedCaregiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No caregiver connected ❗")),
      );
      return;
    }

    CheckInStatus? selectedStatus;
    double moodRating = 3.0;
    String notes = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("How are you feeling?"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select your current status:"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusButton(
                      icon: Icons.check_circle,
                      label: "OK",
                      color: Colors.green,
                      onTap: () {
                        selectedStatus = CheckInStatus.ok;
                        Navigator.pop(context);
                      },
                    ),
                    _buildStatusButton(
                      icon: Icons.warning,
                      label: "Need Help",
                      color: Colors.orange,
                      onTap: () {
                        selectedStatus = CheckInStatus.needHelp;
                        Navigator.pop(context);
                      },
                    ),
                    _buildStatusButton(
                      icon: Icons.emergency,
                      label: "Emergency",
                      color: Colors.red,
                      onTap: () {
                        selectedStatus = CheckInStatus.emergency;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selectedStatus == null) return;

    // Show additional info dialog for non-emergency
    if (selectedStatus != CheckInStatus.emergency) {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Additional Information"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Rate your mood (1-5):"),
                  Slider(
                    value: moodRating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: moodRating.round().toString(),
                    onChanged: (value) {
                      setStateDialog(() {
                        moodRating = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: "Add notes (optional)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      notes = value;
                    },
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Skip"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Submit"),
                ),
              ],
            );
          },
        ),
      );
    }

    try {
      await _checkinService.sendCheckIn(
        caregiverId: connectedCaregiverId!,
        status: selectedStatus!,
        notes: notes.isNotEmpty ? notes : null,
        moodRating: moodRating,
      );

      String message;
      Color color;
      if (selectedStatus == CheckInStatus.ok) {
        message = "Check-in sent successfully ✅";
        color = Colors.green;
      } else if (selectedStatus == CheckInStatus.needHelp) {
        message = "Help request sent! Caregiver has been notified ⚠️";
        color = Colors.orange;
      } else {
        message = "EMERGENCY! Caregiver has been alerted 🚨";
        color = Colors.red;

        // Also send an alert for emergency
        await _alertService.sendAlert(
          receiverId: connectedCaregiverId!,
          title: "EMERGENCY ALERT",
          message: "Emergency check-in triggered by elderly user",
          priority: AlertPriority.emergency,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: color),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatusButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void sendRequest(String caregiverId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _connectionService.sendRequest(
        elderlyId: user.uid,
        caregiverId: caregiverId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request sent successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToChat() {
    if (connectedCaregiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No caregiver connected yet")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: connectedCaregiverId!,
          otherUserName: connectedCaregiver?['fullName'] ?? 'Caregiver',
          otherUserImage: connectedCaregiver?['profileImageUrl'] ?? '',
        ),
      ),
    );
  }

  void _navigateToAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlertsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

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
          // Chat button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: _navigateToChat,
              ),
              if (_unreadMessages > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadMessages > 9 ? '9+' : '$_unreadMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // Alerts button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _navigateToAlerts,
              ),
              if (_unreadAlerts > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadAlerts > 9 ? '9+' : '$_unreadAlerts',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CaregiverSearchDelegate(
                  onConnect: sendRequest,
                  currentUserId: user.uid,
                ),
              );
            },
          ),

          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) => _loadUserData());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
          await _loadConnectedCaregiver();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!isLoading && userData != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            userData!["fullName"]?[0]?.toUpperCase() ?? "U",
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Welcome, ${userData!["fullName"] ?? "User"}!",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (connectedCaregiver != null)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 16, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  "Connected to: ${connectedCaregiver!['fullName']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Quick Actions
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickAction(
                            icon: Icons.favorite,
                            label: "Check-in",
                            color: Colors.red,
                            onTap: sendCheckIn,
                          ),
                          _buildQuickAction(
                            icon: Icons.chat,
                            label: "Message",
                            color: Colors.blue,
                            onTap: _navigateToChat,
                          ),
                          _buildQuickAction(
                            icon: Icons.warning,
                            label: "Alert",
                            color: Colors.orange,
                            onTap: _navigateToAlerts,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Connection Status
              if (connectedCaregiver == null)
                Card(
                  color: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add,
                            size: 48, color: Colors.orange),
                        const SizedBox(height: 8),
                        const Text(
                          "No Caregiver Connected",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Use the search icon to find and connect with a caregiver",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: CaregiverSearchDelegate(
                                onConnect: sendRequest,
                                currentUserId: user.uid,
                              ),
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text("Find Caregiver"),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
