import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 👇 Elderly sends request to caregiver
  Future<void> sendRequest({
    required String elderlyId,
    required String caregiverId,
  }) async {
    await _firestore.collection("connections").add({
      "elderlyId": elderlyId,
      "caregiverId": caregiverId,
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // 👇 Caregiver accepts request
  Future<void> acceptRequest(String connectionId) async {
    await _firestore.collection("connections").doc(connectionId).update({
      "status": "accepted",
    });
  }

  // 👇 Get caregiver connections
  Stream<QuerySnapshot> caregiverConnections(String caregiverId) {
    return _firestore
        .collection("connections")
        .where("caregiverId", isEqualTo: caregiverId)
        .snapshots();
  }

  // 👇 Get elderly connections
  Stream<QuerySnapshot> elderlyConnections(String elderlyId) {
    return _firestore
        .collection("connections")
        .where("elderlyId", isEqualTo: elderlyId)
        .snapshots();
  }
}
