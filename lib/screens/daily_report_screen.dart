import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/checkin_service.dart';
import '../services/alert_service.dart';

class DailyReportScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const DailyReportScreen({
    Key? key,
    required this.elderlyId,
    required this.elderlyName,
  }) : super(key: key);

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final CheckinService _checkinService = CheckinService();
  final AlertService _alertService = AlertService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  List<QueryDocumentSnapshot> _checkins = [];
  List<QueryDocumentSnapshot> _alerts = [];
  List<QueryDocumentSnapshot> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      // Load check-ins
      final checkinsSnapshot = await FirebaseFirestore.instance
          .collection('checkins')
          .where('elderlyId', isEqualTo: widget.elderlyId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();
      _checkins = checkinsSnapshot.docs;

      // Load alerts
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('alerts')
          .where('senderId', isEqualTo: widget.elderlyId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();
      _alerts = alertsSnapshot.docs;

      // Load reminders
      final remindersSnapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('elderlyId', isEqualTo: widget.elderlyId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();
      _reminders = remindersSnapshot.docs;

      // Get statistics
      final stats = await _checkinService.getCheckInStats(widget.elderlyId);
      _reportData = stats;
    } catch (e) {
      print('Error loading report data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _exportReport() async {
    // Implement PDF export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Report - ${widget.elderlyName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildCheckInsCard(),
                        const SizedBox(height: 16),
                        _buildAlertsCard(),
                        const SizedBox(height: 16),
                        _buildRemindersCard(),
                        const SizedBox(height: 16),
                        _buildRecommendationsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                _loadReportData();
              });
            },
          ),
          Column(
            children: [
              Text(
                DateFormat('EEEE').format(_selectedDate),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                DateFormat('MMM d, yyyy').format(_selectedDate),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              if (_selectedDate.isBefore(DateTime.now())) {
                setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                  _loadReportData();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final okCount = _checkins.where((doc) => doc['status'] == 'ok').length;
    final needHelpCount =
        _checkins.where((doc) => doc['status'] == 'needHelp').length;
    final emergencyCount =
        _checkins.where((doc) => doc['status'] == 'emergency').length;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.favorite,
                  label: 'Check-ins',
                  value: _checkins.length.toString(),
                  color: Colors.red,
                ),
                _buildStatItem(
                  icon: Icons.notifications_active,
                  label: 'Alerts',
                  value: _alerts.length.toString(),
                  color: Colors.orange,
                ),
                _buildStatItem(
                  icon: Icons.notifications, // Changed from Icons.reminder
                  label: 'Reminders',
                  value: _reminders.length.toString(),
                  color: Colors.blue,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem('✅ OK', okCount, Colors.green),
                _buildStatusItem('⚠️ Need Help', needHelpCount, Colors.orange),
                _buildStatusItem('🚨 Emergency', emergencyCount, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildCheckInsCard() {
    if (_checkins.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No check-ins recorded for this day'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Check-ins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _checkins.length,
              itemBuilder: (context, index) {
                final checkin = _checkins[index].data() as Map<String, dynamic>;
                final timestamp =
                    (checkin['timestamp'] as Timestamp?)?.toDate();
                final status = checkin['status'] ?? 'ok';

                return ListTile(
                  leading: Icon(
                    status == 'ok'
                        ? Icons.check_circle
                        : status == 'needHelp'
                            ? Icons.warning
                            : Icons.emergency,
                    color: status == 'ok'
                        ? Colors.green
                        : status == 'needHelp'
                            ? Colors.orange
                            : Colors.red,
                  ),
                  title: Text(
                    status == 'ok'
                        ? 'Feeling OK'
                        : status == 'needHelp'
                            ? 'Needs Assistance'
                            : 'Emergency!',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    timestamp != null
                        ? DateFormat('h:mm a').format(timestamp)
                        : 'Time unknown',
                  ),
                  trailing: checkin['moodRating'] != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text('${checkin['moodRating']}/5'),
                          ],
                        )
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard() {
    if (_alerts.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No alerts sent on this day'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index].data() as Map<String, dynamic>;
                final timestamp = (alert['timestamp'] as Timestamp?)?.toDate();
                final priority = alert['priority'] ?? 'medium';

                return ListTile(
                  leading: Icon(
                    priority == 'low'
                        ? Icons.info_outline
                        : priority == 'medium'
                            ? Icons.warning_amber_outlined
                            : priority == 'high'
                                ? Icons.warning
                                : Icons.emergency,
                    color: priority == 'low'
                        ? Colors.blue
                        : priority == 'medium'
                            ? Colors.orange
                            : priority == 'high'
                                ? Colors.red
                                : Colors.deepOrange,
                  ),
                  title: Text(
                    alert['title'] ?? 'Alert',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        timestamp != null
                            ? DateFormat('h:mm a').format(timestamp)
                            : 'Time unknown',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersCard() {
    if (_reminders.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No reminders scheduled for this day'),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder =
                    _reminders[index].data() as Map<String, dynamic>;
                final timestamp =
                    (reminder['timestamp'] as Timestamp?)?.toDate();
                final isCompleted = reminder['isCompleted'] ?? false;
                final type = reminder['type'] ?? 'general';

                return ListTile(
                  leading: Icon(
                    type == 'medication'
                        ? Icons.medication
                        : type == 'wellness'
                            ? Icons.health_and_safety
                            : Icons.notifications,
                    color: isCompleted ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    reminder['message'] ?? 'Reminder',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    timestamp != null
                        ? DateFormat('h:mm a').format(timestamp)
                        : 'Time unknown',
                  ),
                  trailing: isCompleted
                      ? const Chip(
                          label: Text('Completed'),
                          backgroundColor: Colors.green,
                          labelStyle:
                              TextStyle(color: Colors.white, fontSize: 10),
                        )
                      : const Chip(
                          label: Text('Pending'),
                          backgroundColor: Colors.orange,
                          labelStyle:
                              TextStyle(color: Colors.white, fontSize: 10),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final okRate = _reportData['okRate'] ?? 0;
    final needHelpRate = _reportData['needHelpRate'] ?? 0;
    final averageMood = _reportData['averageMood'] ?? 3;

    List<String> recommendations = [];

    if (needHelpRate > 0.3) {
      recommendations.add(
          '• High rate of assistance needed - consider increasing check-in frequency');
    }

    if (averageMood < 2.5) {
      recommendations.add(
          '• Low mood rating detected - consider wellness activities or counseling');
    }

    if (_alerts.length > 3) {
      recommendations.add(
          '• Multiple alerts sent - review alert patterns and address underlying issues');
    }

    if (recommendations.isEmpty) {
      recommendations
          .add('• All metrics look good! Continue with current care plan');
      recommendations.add('• Maintain regular communication and check-ins');
    }

    recommendations
        .add('• Schedule a follow-up call to discuss weekly progress');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Recommendations & Insights',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(rec, style: const TextStyle(height: 1.5)),
                )),
          ],
        ),
      ),
    );
  }
}
