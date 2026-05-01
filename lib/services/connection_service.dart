import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConnectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Elderly sends request to caregiver
  Future<void> sendRequest({
    required String elderlyId,
    required String caregiverId,
  }) async {
    try {
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
        "isActive": true,
        "isPrimary": false,
      });
    } catch (e) {
      throw Exception("Failed to send request: $e");
    }
  }

  // Caregiver accepts request
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

  // Caregiver rejects request
  Future<void> rejectRequest(String connectionId) async {
    try {
      await _firestore.collection("connections").doc(connectionId).delete();
    } catch (e) {
      throw Exception("Failed to reject request: $e");
    }
  }

  // Get all accepted connections for elderly (multiple caregivers)
  Stream<List<Map<String, dynamic>>> getElderlyConnections(String elderlyId) {
    return _firestore
        .collection("connections")
        .where("elderlyId", isEqualTo: elderlyId)
        .where("status", isEqualTo: "accepted")
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> connections = [];
      for (var doc in snapshot.docs) {
        final caregiverId = doc["caregiverId"];
        final caregiverDoc =
            await _firestore.collection("users").doc(caregiverId).get();

        if (caregiverDoc.exists) {
          connections.add({
            "connectionId": doc.id,
            "caregiverId": caregiverId,
            "caregiverData": caregiverDoc.data(),
            "isPrimary": doc["isPrimary"] ?? false,
            "acceptedAt": doc["acceptedAt"],
          });
        }
      }
      return connections;
    });
  }

  // Get all accepted connections for caregiver (multiple elderly)
  Stream<List<Map<String, dynamic>>> getCaregiverConnections(
      String caregiverId) {
    return _firestore
        .collection("connections")
        .where("caregiverId", isEqualTo: caregiverId)
        .where("status", isEqualTo: "accepted")
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> connections = [];
      for (var doc in snapshot.docs) {
        final elderlyId = doc["elderlyId"];
        final elderlyDoc =
            await _firestore.collection("users").doc(elderlyId).get();

        if (elderlyDoc.exists) {
          connections.add({
            "connectionId": doc.id,
            "elderlyId": elderlyId,
            "elderlyData": elderlyDoc.data(),
            "acceptedAt": doc["acceptedAt"],
          });
        }
      }
      return connections;
    });
  }

  // Set primary caregiver for elderly
  Future<void> setPrimaryCaregiver(String elderlyId, String caregiverId) async {
    try {
      final connections = await _firestore
          .collection("connections")
          .where("elderlyId", isEqualTo: elderlyId)
          .where("status", isEqualTo: "accepted")
          .get();

      final batch = _firestore.batch();
      for (var doc in connections.docs) {
        if (doc["caregiverId"] == caregiverId) {
          batch.update(doc.reference, {"isPrimary": true});
        } else {
          batch.update(doc.reference, {"isPrimary": false});
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception("Failed to set primary caregiver: $e");
    }
  }

  // Get pending requests for caregiver
  Stream<QuerySnapshot> getPendingRequests(String caregiverId) {
    return _firestore
        .collection("connections")
        .where("caregiverId", isEqualTo: caregiverId)
        .where("status", isEqualTo: "pending")
        .snapshots();
  }

  // Remove connection
  Future<void> removeConnection(String connectionId) async {
    try {
      await _firestore.collection("connections").doc(connectionId).delete();
    } catch (e) {
      throw Exception("Failed to remove connection: $e");
    }
  }
}
