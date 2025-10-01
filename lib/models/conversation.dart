// lib/models/conversation.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final String requestId;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final bool isActive;
  final String lastSenderId;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.requestId,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.isActive,
    required this.lastSenderId,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'requestId': requestId,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'isActive': isActive,
      'lastSenderId': lastSenderId,
    };
  }

  // Create ConversationModel from Firebase document
  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      requestId: map['requestId'] ?? '',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: (map['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      lastSenderId: map['lastSenderId'] ?? '',
    );
  }
  
  // Helper method to get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}