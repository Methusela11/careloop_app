import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    if (currentUser == null) return;

    await _firestore.collection('checkins').add({
      'elderlyId': currentUser.uid,
      'caregiverId': caregiverId,
      'status': status.toString().split('.').last,
      'notes': notes ?? '',
      'moodRating': moodRating ?? 3.0,
      'timestamp': FieldValue.serverTimestamp(),
      'isResponded': false,
    });
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

  // Respond to check-in
  Future<void> respondToCheckIn(String checkInId, String response) async {
    await _firestore.collection('checkins').doc(checkInId).update({
      'caregiverResponse': response,
      'isResponded': true,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get check-in statistics
  Future<Map<String, dynamic>> getCheckInStats(String elderlyId) async {
    final checkins = await _firestore
        .collection('checkins')
        .where('elderlyId', isEqualTo: elderlyId)
        .where('timestamp',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
        .get();

    final total = checkins.docs.length;
    final okCount = checkins.docs.where((doc) => doc['status'] == 'ok').length;
    final needHelpCount =
        checkins.docs.where((doc) => doc['status'] == 'needHelp').length;
    final emergencyCount =
        checkins.docs.where((doc) => doc['status'] == 'emergency').length;

    return {
      'total': total,
      'okRate': total > 0 ? okCount / total : 0,
      'needHelpRate': total > 0 ? needHelpCount / total : 0,
      'emergencyRate': total > 0 ? emergencyCount / total : 0,
      'averageMood': checkins.docs
              .fold<double>(0, (sum, doc) => sum + (doc['moodRating'] ?? 3)) /
          (total > 0 ? total : 1),
    };
  }
}

enum CheckInStatus {
  ok,
  needHelp,
  emergency,
}
