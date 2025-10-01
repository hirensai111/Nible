// lib/models/user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String name;
  final double walletBalance;
  final int deliveriesMade;
  final double averageRating;
  final double totalEarned;
  final int deliveriesUntilHokieHero;
  String? userId; // For Firebase
  String? email;
  String? profileImageUrl;

  UserModel({
    required this.name,
    required this.walletBalance,
    required this.deliveriesMade,
    required this.averageRating,
    required this.totalEarned,
    required this.deliveriesUntilHokieHero,
    this.userId,
    this.email,
    this.profileImageUrl,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'walletBalance': walletBalance,
      'deliveriesMade': deliveriesMade,
      'averageRating': averageRating,
      'totalEarned': totalEarned,
      'deliveriesUntilHokieHero': deliveriesUntilHokieHero,
      'email': email,
      'profileImageUrl': profileImageUrl,
    };
  }

  // Create UserModel from Firebase document
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      walletBalance: (map['walletBalance'] ?? 0.0).toDouble(),
      deliveriesMade: map['deliveriesMade'] ?? 0,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      totalEarned: (map['totalEarned'] ?? 0.0).toDouble(),
      deliveriesUntilHokieHero: map['deliveriesUntilHokieHero'] ?? 0,
      email: map['email'],
      profileImageUrl: map['profileImageUrl'],
    );
  }
}

// lib/models/delivery.dart

class DeliveryModel {
  final String id;
  final String pickupLocation;
  final String dropoffLocation;
  final int itemCount;
  final double distance;
  final int estimatedTime;
  final double fee;
  
  // Additional fields for Firebase integration
  String? requesterId;
  String? delivererId;
  String? status; // "available", "accepted", "in_progress", "completed", "cancelled"
  DateTime? createdAt;
  DateTime? updatedAt;
  String? notes;
  List<String>? itemDetails;

  DeliveryModel({
    required this.id,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.itemCount,
    required this.distance,
    required this.estimatedTime,
    required this.fee,
    this.requesterId,
    this.delivererId,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.notes,
    this.itemDetails,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'itemCount': itemCount,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'fee': fee,
      'requesterId': requesterId,
      'delivererId': delivererId,
      'status': status ?? 'available',
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'notes': notes,
      'itemDetails': itemDetails,
    };
  }

  // Create DeliveryModel from Firebase document
  factory DeliveryModel.fromMap(Map<String, dynamic> map, String id) {
    return DeliveryModel(
      id: id,
      pickupLocation: map['pickupLocation'] ?? '',
      dropoffLocation: map['dropoffLocation'] ?? '',
      itemCount: map['itemCount'] ?? 0,
      distance: (map['distance'] ?? 0.0).toDouble(),
      estimatedTime: map['estimatedTime'] ?? 0,
      fee: (map['fee'] ?? 0.0).toDouble(),
      requesterId: map['requesterId'],
      delivererId: map['delivererId'],
      status: map['status'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      itemDetails: List<String>.from(map['itemDetails'] ?? []),
    );
  }
}