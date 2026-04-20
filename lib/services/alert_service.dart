import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send alert from elderly to caregiver or vice versa
  Future<void> sendAlert({
    required String receiverId,
    required String title,
    required String message,
    required AlertPriority priority,
    String? imageUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('alerts').add({
      'senderId': currentUser.uid,
      'receiverId': receiverId,
      'title': title,
      'message': message,
      'priority': priority.toString().split('.').last,
      'imageUrl': imageUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isAcknowledged': false,
      'type': 'alert',
    });
  }

  // Get alerts for current user
  Stream<QuerySnapshot> getAlerts() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.empty();

    return _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark alert as read
  Future<void> markAlertAsRead(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isRead': true,
    });
  }

  // Acknowledge alert
  Future<void> acknowledgeAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'isAcknowledged': true,
      'acknowledgedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get unread alerts count
  Stream<int> getUnreadAlertsCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _firestore
        .collection('alerts')
        .where('receiverId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

enum AlertPriority {
  low,
  medium,
  high,
  emergency,
}
