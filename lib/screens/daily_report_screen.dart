import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/checkin_service.dart';
import '../services/alert_service.dart';

class DailyReportScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const DailyReportScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final CheckinService _checkinService = CheckinService();
  final AlertService _alertService = AlertService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _checkins = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _alerts = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reminders = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
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
      debugPrint('Error loading report data: $e');
      setState(() {
        _errorMessage = 'Failed to load report data: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select Report Date',
      cancelText: 'Cancel',
      confirmText: 'OK',
      fieldHintText: 'MM/DD/YYYY',
      fieldLabelText: 'Date',
    );

    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Report - ${widget.elderlyName}'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading report data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReportData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
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
    );
  }

  Widget _buildDateSelector() {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
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
              });
              _loadReportData();
            },
            tooltip: 'Previous Day',
          ),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(fontSize: 10, color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final nextDay = _selectedDate.add(const Duration(days: 1));
              final today = DateTime.now();
              final isNextDayValid = nextDay.isBefore(today) ||
                  (nextDay.year == today.year &&
                      nextDay.month == today.month &&
                      nextDay.day == today.day);

              if (isNextDayValid) {
                setState(() {
                  _selectedDate = nextDay;
                });
                _loadReportData();
              }
            },
            tooltip: 'Next Day',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final okCount = _checkins
        .where((doc) => (doc.data()['status'] as String?) == 'ok')
        .length;
    final needHelpCount = _checkins
        .where((doc) => (doc.data()['status'] as String?) == 'needHelp')
        .length;
    final emergencyCount = _checkins
        .where((doc) => (doc.data()['status'] as String?) == 'emergency')
        .length;

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
                  icon: Icons.notifications,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: color),
        ),
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No check-ins recorded for this day',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
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
                final checkinData = _checkins[index].data();
                final timestamp = checkinData['timestamp'] as Timestamp?;
                final status = checkinData['status'] as String? ?? 'ok';
                final notes = checkinData['notes'] as String? ?? '';
                final moodRating = checkinData['moodRating'] as double? ?? 3.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: status == 'ok'
                            ? Colors.green.withOpacity(0.1)
                            : status == 'needHelp'
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
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
                        size: 24,
                      ),
                    ),
                    title: Text(
                      status == 'ok'
                          ? 'Feeling OK'
                          : status == 'needHelp'
                              ? 'Needs Assistance'
                              : 'Emergency!',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timestamp != null
                              ? DateFormat('h:mm a').format(timestamp.toDate())
                              : 'Time unknown',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (notes.isNotEmpty)
                          Text(
                            notes,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                    trailing: moodRating != 3.0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text('${moodRating.round()}/5'),
                            ],
                          )
                        : null,
                  ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No alerts sent on this day',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
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
                final alertData = _alerts[index].data();
                final timestamp = alertData['timestamp'] as Timestamp?;
                final priority = alertData['priority'] as String? ?? 'medium';
                final title = alertData['title'] as String? ?? 'Alert';
                final message = alertData['message'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getAlertColor(priority).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getAlertIcon(priority),
                        color: _getAlertColor(priority),
                        size: 24,
                      ),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message),
                        const SizedBox(height: 4),
                        Text(
                          timestamp != null
                              ? DateFormat('h:mm a').format(timestamp.toDate())
                              : 'Time unknown',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No reminders scheduled for this day',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
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
                final reminderData = _reminders[index].data();
                final timestamp = reminderData['timestamp'] as Timestamp?;
                final isCompleted =
                    reminderData['isCompleted'] as bool? ?? false;
                final type = reminderData['type'] as String? ?? 'general';
                final message =
                    reminderData['message'] as String? ?? 'Reminder';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        type == 'medication'
                            ? Icons.medication
                            : type == 'wellness'
                                ? Icons.health_and_safety
                                : Icons.notifications,
                        color: isCompleted ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      message,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      timestamp != null
                          ? DateFormat('h:mm a').format(timestamp.toDate())
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
    final okRate = (_reportData['okRate'] as num?)?.toDouble() ?? 0.0;
    final needHelpRate =
        (_reportData['needHelpRate'] as num?)?.toDouble() ?? 0.0;
    final averageMood = (_reportData['averageMood'] as num?)?.toDouble() ?? 3.0;

    List<String> recommendations = [];

    if (needHelpRate > 0.3) {
      recommendations.add(
        '• High rate of assistance needed (${(needHelpRate * 100).toInt()}%) - consider increasing check-in frequency',
      );
    }

    if (averageMood < 2.5) {
      recommendations.add(
        '• Low mood rating detected (${averageMood.round()}/5) - consider wellness activities or counseling',
      );
    }

    if (_alerts.length > 3) {
      recommendations.add(
        '• Multiple alerts sent (${_alerts.length}) - review alert patterns and address underlying issues',
      );
    }

    if (_checkins.isEmpty) {
      recommendations
          .add('• No check-ins recorded today - encourage regular check-ins');
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
                  child: Text(
                    rec,
                    style: const TextStyle(height: 1.5),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  IconData _getAlertIcon(String priority) {
    switch (priority.toLowerCase()) {
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

  Color _getAlertColor(String priority) {
    switch (priority.toLowerCase()) {
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
