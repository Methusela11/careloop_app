import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final AlertService _alertService = AlertService();
  final AuthService _authService = AuthService();
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = _authService.getCurrentUser();
    setState(() {
      currentUserId = user?.uid;
    });
  }

  Future<void> _sendNewAlert() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController messageController = TextEditingController();
    AlertPriority selectedPriority = AlertPriority.medium;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send New Alert'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Alert Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Alert Message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AlertPriority>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: AlertPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            _getPriorityIcon(priority),
                            color: _getPriorityColor(priority),
                          ),
                          const SizedBox(width: 8),
                          Text(priority
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase()),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setStateDialog(() {
                        selectedPriority = value;
                      });
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // For demo, send to all connected users
              await _alertService.sendAlert(
                receiverId: 'caregiver_id_here', // Get from connections
                title: titleController.text,
                message: messageController.text,
                priority: selectedPriority,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alert sent successfully')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            onPressed: _sendNewAlert,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _alertService.getAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!.docs;

          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No alerts yet'),
                  Text('Alerts will appear here',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index].data() as Map<String, dynamic>;
              final timestamp = (alert['timestamp'] as Timestamp?)?.toDate();
              final priority = alert['priority'] ?? 'medium';
              final isRead = alert['isRead'] ?? false;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(alert['senderId'])
                    .get(),
                builder: (context, senderSnap) {
                  if (!senderSnap.hasData) {
                    return const SizedBox.shrink();
                  }

                  final senderData =
                      senderSnap.data!.data() as Map<String, dynamic>;
                  final senderName = senderData['fullName'] ?? 'Unknown';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    color: isRead ? null : Colors.red.shade50,
                    child: InkWell(
                      onTap: () async {
                        if (!isRead) {
                          await _alertService.markAlertAsRead(alerts[index].id);
                        }
                        _showAlertDetails(alert, senderName, timestamp);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getPriorityIconFromString(priority),
                                  color: _getPriorityColorFromString(priority),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    alert['title'] ?? 'Alert',
                                    style: TextStyle(
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              alert['message'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  senderName,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  timestamp != null
                                      ? DateFormat('MMM d, HH:mm')
                                          .format(timestamp)
                                      : 'Just now',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAlertDetails(
      Map<String, dynamic> alert, String senderName, DateTime? timestamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert['title'] ?? 'Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: $senderName'),
            const SizedBox(height: 8),
            Text('Priority: ${alert['priority']?.toUpperCase() ?? 'MEDIUM'}'),
            const SizedBox(height: 8),
            Text(
                'Time: ${timestamp != null ? DateFormat('MMM d, yyyy HH:mm').format(timestamp) : 'Just now'}'),
            const Divider(),
            Text(alert['message'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!alert['isAcknowledged'])
            ElevatedButton(
              onPressed: () async {
                await _alertService.acknowledgeAlert(alert['id'] as String);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alert acknowledged')),
                  );
                }
              },
              child: const Text('Acknowledge'),
            ),
        ],
      ),
    );
  }

  IconData _getPriorityIcon(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return Icons.info_outline;
      case AlertPriority.medium:
        return Icons.warning_amber_outlined;
      case AlertPriority.high:
        return Icons.warning;
      case AlertPriority.emergency:
        return Icons.emergency;
    }
  }

  Color _getPriorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.low:
        return Colors.blue;
      case AlertPriority.medium:
        return Colors.orange;
      case AlertPriority.high:
        return Colors.red;
      case AlertPriority.emergency:
        return Colors.deepOrange;
    }
  }

  IconData _getPriorityIconFromString(String priority) {
    switch (priority) {
      case 'low':
        return Icons.info_outline;
      case 'medium':
        return Icons.warning_amber_outlined;
      case 'high':
        return Icons.warning;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.notifications;
    }
  }

  Color _getPriorityColorFromString(String priority) {
    switch (priority) {
      case 'low':
        return Colors.blue;
      case 'medium':
        return Colors.orange;
      case 'high':
        return Colors.red;
      case 'emergency':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }
}
