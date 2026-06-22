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

class _ElderlyHomeState extends State<ElderlyHome> {
  final ConnectionService _connectionService = ConnectionService();
  final AuthService _authService = AuthService();
  final CheckinService _checkinService = CheckinService();
  final AlertService _alertService = AlertService();
  final MessageService _messageService = MessageService();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _unreadMessages = 0;
  int _unreadAlerts = 0;
  List<Map<String, dynamic>> _connectedCaregivers = [];
  Map<String, dynamic>? _selectedCaregiver;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadConnectedCaregivers();
    _loadUnreadCounts();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final data = await _authService.getUserData(user.uid);
        if (mounted) {
          setState(() {
            userData = data;
            isLoading = false;
            _errorMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isLoading = false;
            _errorMessage = "Failed to load user data: $e";
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = "Not logged in";
        });
      }
    }
  }

  Future<void> _loadConnectedCaregivers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      _connectionService.getElderlyConnections(user.uid).listen((caregivers) {
        if (mounted) {
          setState(() {
            _connectedCaregivers = caregivers;
            if (_selectedCaregiver == null && caregivers.isNotEmpty) {
              _selectedCaregiver = caregivers.firstWhere(
                (c) => c['isPrimary'] == true,
                orElse: () => caregivers.first,
              );
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load caregivers: $e";
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

  void _selectCaregiver(Map<String, dynamic> caregiver) {
    setState(() {
      _selectedCaregiver = caregiver;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Switched to ${caregiver['caregiverData']['fullName']}"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _navigateToChat() {
    if (_selectedCaregiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No caregiver selected")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: _selectedCaregiver!['caregiverId'],
          otherUserName:
              _selectedCaregiver!['caregiverData']['fullName'] ?? 'Caregiver',
          otherUserImage:
              _selectedCaregiver!['caregiverData']['profileImageUrl'] ?? '',
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

  Future<void> _sendCheckIn() async {
    if (_selectedCaregiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No caregiver selected")),
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
        caregiverId: _selectedCaregiver!['caregiverId'],
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

        await _alertService.sendAlert(
          receiverId: _selectedCaregiver!['caregiverId'],
          title: "EMERGENCY ALERT!!",
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
              color: color.withValues(alpha: 0.1),
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

  Future<void> sendRequest(String caregiverId) async {
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    if (_errorMessage != null && isLoading == false) {
      return Scaffold(
        appBar: AppBar(title: const Text("Elderly Dashboard")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _loadUserData();
                  _loadConnectedCaregivers();
                },
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
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
          // Caregiver selector dropdown
          if (_connectedCaregivers.length > 1)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCaregiver?['caregiverId'],
                  icon: const Icon(Icons.swap_horiz, color: Colors.white),
                  dropdownColor: Colors.white,
                  onChanged: (String? newValue) {
                    final newCaregiver = _connectedCaregivers.firstWhere(
                      (c) => c['caregiverId'] == newValue,
                    );
                    _selectCaregiver(newCaregiver);
                  },
                  items: _connectedCaregivers.map((caregiver) {
                    return DropdownMenuItem<String>(
                      value: caregiver['caregiverId'],
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: caregiver['caregiverData']
                                            ['profileImageUrl']
                                        ?.isNotEmpty ==
                                    true
                                ? NetworkImage(caregiver['caregiverData']
                                    ['profileImageUrl'])
                                : null,
                            child: caregiver['caregiverData']['profileImageUrl']
                                        ?.isEmpty !=
                                    false
                                ? Text(
                                    caregiver['caregiverData']['fullName'][0]
                                        .toUpperCase(),
                                    style: const TextStyle(fontSize: 10))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(caregiver['caregiverData']['fullName'] ??
                              'Caregiver'),
                          if (caregiver['isPrimary'] == true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

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
          await _loadConnectedCaregivers();
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
                        if (_selectedCaregiver != null)
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
                                  "Active: ${_selectedCaregiver!['caregiverData']['fullName']}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        if (_connectedCaregivers.length > 1)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "${_connectedCaregivers.length} Caregivers Connected",
                              style: const TextStyle(fontSize: 12),
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
                            onTap: _sendCheckIn,
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

              // Connected Caregivers List
              if (_connectedCaregivers.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Your Caregivers",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._connectedCaregivers.map((caregiver) {
                          final data = caregiver['caregiverData'];
                          final isSelected =
                              _selectedCaregiver?['caregiverId'] ==
                                  caregiver['caregiverId'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    data['profileImageUrl']?.isNotEmpty == true
                                        ? NetworkImage(data['profileImageUrl'])
                                        : null,
                                child: data['profileImageUrl']?.isEmpty != false
                                    ? Text(data['fullName'][0].toUpperCase())
                                    : null,
                              ),
                              title: Text(
                                data['fullName'] ?? 'Caregiver',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle:
                                  Text('@${data['username'] ?? 'unknown'}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (caregiver['isPrimary'] == true)
                                    const Chip(
                                      label: Text('Primary'),
                                      backgroundColor: Colors.green,
                                      labelStyle: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  const SizedBox(width: 8),
                                  if (!isSelected)
                                    ElevatedButton(
                                      onPressed: () =>
                                          _selectCaregiver(caregiver),
                                      child: const Text("Switch"),
                                    ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),

              // No Caregivers Connected State
              if (_connectedCaregivers.isEmpty)
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
                          "No Caregivers Connected",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Use the search icon to find and connect with caregivers",
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
                                existingCaregiverIds: _connectedCaregivers
                                    .map((c) => c['caregiverId'] as String)
                                    .toList(),
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
                color: color.withValues(alpha: 0.1),
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

// Search Delegate for Caregiver Search
class CaregiverSearchDelegate extends SearchDelegate {
  final Function(String) onConnect;
  final String currentUserId;
  final List<String> existingCaregiverIds;

  CaregiverSearchDelegate({
    required this.onConnect,
    required this.currentUserId,
    required this.existingCaregiverIds,
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

    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final caregiverId = data["uid"] ?? doc.id;

      if (existingCaregiverIds.contains(caregiverId)) {
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Error: ${snapshot.error}"),
                ElevatedButton(
                  onPressed: () => showResults(context),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        final results = snapshot.data!;

        if (results.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No caregivers found"),
                SizedBox(height: 8),
                Text("Try a different search term"),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final user = results[index];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: user["profileImageUrl"].isNotEmpty
                      ? NetworkImage(user["profileImageUrl"])
                      : null,
                  child: user["profileImageUrl"].isEmpty
                      ? Text(
                          user["fullName"][0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
                        )
                      : null,
                ),
                title: Text(
                  user["fullName"],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("@${user["username"]}"),
                trailing: ElevatedButton.icon(
                  onPressed: () {
                    close(context, null);
                    onConnect(user["uid"]);
                  },
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text("Connect"),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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
          Text(
            "Search by name, username or email",
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            "Find caregivers to connect with",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
