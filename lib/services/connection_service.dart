import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 👇 Caregiver rejects request
  Future<void> rejectRequest(String connectionId) async {
    try {
      await _firestore.collection("connections").doc(connectionId).delete();
    } catch (e) {
      throw Exception("Failed to reject request: $e");
    }
  }

  // 👇 Elderly sends request to caregiver
  Future<void> sendRequest({
    required String elderlyId,
    required String caregiverId,
  }) async {
    try {
      // Check if connection already exists
      final existingConnection = await _firestore
          .collection("connections")
          .where("elderlyId", isEqualTo: elderlyId)
          .where("caregiverId", isEqualTo: caregiverId)
          .get();

      if (existingConnection.docs.isNotEmpty) {
        final status = existingConnection.docs.first["status"];
        if (status == "pending") {
          throw Exception("Request already sent and pending");
        } else if (status == "accepted") {
          throw Exception("Already connected with this caregiver");
        }
      }

      await _firestore.collection("connections").add({
        "elderlyId": elderlyId,
        "caregiverId": caregiverId,
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Failed to send request: $e");
    }
  }

  // 👇 Caregiver accepts request
  Future<void> acceptRequest(String connectionId) async {
    try {
      await _firestore.collection("connections").doc(connectionId).update({
        "status": "accepted",
        "acceptedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception("Failed to accept request: $e");
    }
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

  // 👇 Get connection status between two users
  Future<String?> getConnectionStatus(
      String elderlyId, String caregiverId) async {
    try {
      final query = await _firestore
          .collection("connections")
          .where("elderlyId", isEqualTo: elderlyId)
          .where("caregiverId", isEqualTo: caregiverId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first["status"];
      }
      return null;
    } catch (e) {
      throw Exception("Failed to get connection status: $e");
    }
  }

  // 👇 Disconnect (remove connection)
  Future<void> disconnect(String connectionId) async {
    try {
      await _firestore.collection("connections").doc(connectionId).delete();
    } catch (e) {
      throw Exception("Failed to disconnect: $e");
    }
  }
}
