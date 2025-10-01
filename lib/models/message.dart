// lib/models/message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool read;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.read,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': read,
    };
  }

  // Create MessageModel from Firebase document
  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] ?? false,
    );
  }
}