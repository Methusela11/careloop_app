class CheckIn {
  String userId;
  DateTime timestamp;

  CheckIn({
    required this.userId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}