import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CheckinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send check-in
  Future<void> sendCheckIn({
    required String caregiverId,
    required CheckInStatus status,
    String? notes,
    double? moodRating,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not logged in');

    try {
      await _firestore.collection('checkins').add({
        'elderlyId': currentUser.uid,
        'caregiverId': caregiverId,
        'status': status.toString().split('.').last,
        'notes': notes ?? '',
        'moodRating': moodRating ?? 3.0,
        'timestamp': FieldValue.serverTimestamp(),
        'isResponded': false,
        'caregiverResponse': '',
        'respondedAt': null,
      });
    } catch (e) {
      throw Exception('Failed to send check-in: $e');
    }
  }

  // Get check-ins for caregiver
  Stream<QuerySnapshot> getCheckInsForCaregiver() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();

    return _firestore
        .collection('checkins')
        .where('caregiverId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get check-ins for elderly
  Stream<QuerySnapshot> getCheckInsForElderly() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();

    return _firestore
        .collection('checkins')
        .where('elderlyId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get recent check-ins (last 7 days)
  Future<List<QueryDocumentSnapshot>> getRecentCheckIns(String elderlyId) async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    final snapshot = await _firestore
        .collection('checkins')
        .where('elderlyId', isEqualTo: elderlyId)
        .where('timestamp', isGreaterThan: sevenDaysAgo)
        .orderBy('timestamp', descending: true)
        .get();
    
    return snapshot.docs;
  }

  // Respond to check-in
  Future<void> respondToCheckIn(String checkInId, String response) async {
    try {
      await _firestore.collection('checkins').doc(checkInId).update({
        'caregiverResponse': response,
        'isResponded': true,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to respond to check-in: $e');
    }
  }

  // Get check-in by ID
  Future<Map<String, dynamic>?> getCheckInById(String checkInId) async {
    try {
      final doc = await _firestore.collection('checkins').doc(checkInId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get check-in: $e');
    }
  }

  // Get check-in statistics
  Future<Map<String, dynamic>> getCheckInStats(String elderlyId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final checkins = await _firestore
          .collection('checkins')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('timestamp', isGreaterThan: thirtyDaysAgo)
          .get();

      final total = checkins.docs.length;
      
      if (total == 0) {
        return {
          'total': 0,
          'okRate': 0.0,
          'needHelpRate': 0.0,
          'emergencyRate': 0.0,
          'averageMood': 3.0,
          'okCount': 0,
          'needHelpCount': 0,
          'emergencyCount': 0,
          'responseRate': 0.0,
          'mostCommonTime': 'N/A',
        };
      }
      
      final okCount = checkins.docs.where((doc) => doc['status'] == 'ok').length;
      final needHelpCount = checkins.docs.where((doc) => doc['status'] == 'needHelp').length;
      final emergencyCount = checkins.docs.where((doc) => doc['status'] == 'emergency').length;
      
      // Calculate average mood rating
      double sumMood = 0;
      int moodCount = 0;
      for (var doc in checkins.docs) {
        if (doc['moodRating'] != null) {
          sumMood += (doc['moodRating'] as num).toDouble();
          moodCount++;
        }
      }
      final averageMood = moodCount > 0 ? sumMood / moodCount : 3.0;
      
      // Calculate response rate
      final respondedCount = checkins.docs.where((doc) => doc['isResponded'] == true).length;
      final responseRate = respondedCount / total;
      
      // Find most common check-in time
      final hourCounts = <int, int>{};
      for (var doc in checkins.docs) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final hour = timestamp.toDate().hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        }
      }
      
      String mostCommonTime = 'N/A';
      if (hourCounts.isNotEmpty) {
        final mostCommonHour = hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        mostCommonTime = _formatHour(mostCommonHour);
      }
      
      return {
        'total': total,
        'okRate': okCount / total,
        'needHelpRate': needHelpCount / total,
        'emergencyRate': emergencyCount / total,
        'averageMood': averageMood,
        'okCount': okCount,
        'needHelpCount': needHelpCount,
        'emergencyCount': emergencyCount,
        'responseRate': responseRate,
        'mostCommonTime': mostCommonTime,
      };
    } catch (e) {
      throw Exception('Failed to get check-in stats: $e');
    }
  }

  // Get weekly trend
  Future<Map<String, dynamic>> getWeeklyTrend(String elderlyId) async {
    final weeklyData = <String, Map<String, dynamic>>{};
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      final checkins = await _firestore
          .collection('checkins')
          .where('elderlyId', isEqualTo: elderlyId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThan: endOfDay)
          .get();
      
      final dayName = DateFormat('EEE').format(date);
      final okCount = checkins.docs.where((doc) => doc['status'] == 'ok').length;
      final needHelpCount = checkins.docs.where((doc) => doc['status'] == 'needHelp').length;
      
      weeklyData[dayName] = {
        'total': checkins.docs.length,
        'ok': okCount,
        'needHelp': needHelpCount,
      };
    }
    
    return weeklyData;
  }

  // Delete old check-ins (for maintenance)
  Future<void> deleteOldCheckIns({int daysOld = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final oldCheckins = await _firestore
          .collection('checkins')
          .where('timestamp', isLessThan: cutoffDate)
          .limit(100)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in oldCheckins.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting old check-ins: $e');
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

enum CheckInStatus {
  ok,
  needHelp,
  emergency,
}