// lib/services/firebase_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import '../models/delivery.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth methods
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  Future<User?> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'walletBalance': 0.0,
          'deliveriesMade': 0,
          'ordersPlaced': 0,
          'ordersCompleted': 0,
          'averageRating': 0.0,
          'totalRatings': 0,
          'totalEarned': 0.0,
          'deliveriesUntilHokieHero': 5,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return userCredential.user;
    } catch (e) {
      print('Error creating user: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // User methods
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore
          .collection('users')
          .doc(user.userId)
          .update(user.toMap());
    } catch (e) {
      print('Error updating user profile: $e');
    }
  }

  // Delivery methods
  Future<String?> createDeliveryRequest(DeliveryModel delivery) async {
    try {
      final doc = await _firestore
          .collection('deliveries')
          .add(delivery.toMap());
      return doc.id;
    } catch (e) {
      print('Error creating delivery request: $e');
      return null;
    }
  }

  Stream<List<DeliveryModel>> getAvailableDeliveries() {
    return _firestore
        .collection('deliveries')
        .where('status', isEqualTo: 'available')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DeliveryModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  Future<List<DeliveryModel>> getUserDeliveries(String userId) async {
    try {
      final requestedDeliveries =
          await _firestore
              .collection('deliveries')
              .where('requesterId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get();

      final deliveredDeliveries =
          await _firestore
              .collection('deliveries')
              .where('delivererId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .get();

      final List<DeliveryModel> deliveries = [];

      requestedDeliveries.docs.forEach((doc) {
        deliveries.add(DeliveryModel.fromMap(doc.data(), doc.id));
      });

      deliveredDeliveries.docs.forEach((doc) {
        deliveries.add(DeliveryModel.fromMap(doc.data(), doc.id));
      });

      // Sort by date (newest first)
      deliveries.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

      return deliveries;
    } catch (e) {
      print('Error getting user deliveries: $e');
      return [];
    }
  }

  Future<void> updateDeliveryStatus(
    String deliveryId,
    String status,
    String? delivererId,
  ) async {
    try {
      await _firestore.collection('deliveries').doc(deliveryId).update({
        'status': status,
        'delivererId': delivererId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating delivery status: $e');
    }
  }

  // New method for completing deliveries
  Future<bool> completeDelivery(String requestId, String verificationCode) async {
    try {
      // Verify the request exists and has the correct verification code
      final requestDoc = await _firestore.collection('requests').doc(requestId).get();
      print("Completing delivery for request: $requestId");
      
      if (!requestDoc.exists) {
        print('Request not found');
        return false;
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      
      // Check if verification codes match
      if (requestData['verificationCode'] != verificationCode) {
        print('Verification code mismatch');
        return false;
      }
      
      // Get the necessary IDs from the request
      final String? delivererId = requestData['deliveryPersonId'];
      final String? userId = requestData['userId'];
      print("Deliverer ID: $delivererId, User ID: $userId");
      
      // First check if deliverer exists and has required fields
      if (delivererId != null) {
        final delivererDoc = await _firestore.collection('users').doc(delivererId).get();
        if (delivererDoc.exists) {
          Map<String, dynamic> data = delivererDoc.data() as Map<String, dynamic>;
          // Check if deliveriesMade exists, if not create it with initial value
          if (!data.containsKey('deliveriesMade')) {
            print("deliveriesMade field missing, creating it");
            await _firestore.collection('users').doc(delivererId).update({
              'deliveriesMade': 0,
            });
          }
        }
      }
      
      // Check if customer exists and has required fields
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          // Check if ordersCompleted exists, if not create it
          if (!data.containsKey('ordersCompleted')) {
            print("ordersCompleted field missing, creating it");
            await _firestore.collection('users').doc(userId).update({
              'ordersCompleted': 0,
            });
          }
        }
      }
      
      // Start a batch to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      
      // 1. Update request status to completed
      final requestRef = _firestore.collection('requests').doc(requestId);
      batch.update(requestRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      // 2. Update deliverer stats - increment deliveries count
      if (delivererId != null) {
        final delivererRef = _firestore.collection('users').doc(delivererId);
        batch.update(delivererRef, {
          'deliveriesMade': FieldValue.increment(1),
        });
        
        // Optional: Add earnings to deliverer
        final deliveryFee = requestData['totalFee'] ?? 0.0;
        batch.update(delivererRef, {
          'walletBalance': FieldValue.increment(deliveryFee),
          'totalEarned': FieldValue.increment(deliveryFee),
        });
        
        // Record the transaction
        final transactionRef = _firestore.collection('transactions').doc();
        batch.set(transactionRef, {
          'userId': delivererId,
          'amount': deliveryFee,
          'type': 'credit',
          'label': 'Delivery Earnings (Request #${requestId})',
          'timestamp': FieldValue.serverTimestamp(),
          'date': DateTime.now().toIso8601String(),
        });
      }
      
      // 3. Update customer stats - increment orders completed
      if (userId != null) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'ordersCompleted': FieldValue.increment(1),
        });
      }
      
      // Commit all the updates
      await batch.commit();
      print("Delivery completed successfully!");
      
      return true;
    } catch (e) {
      print('Error completing delivery: $e');
      return false;
    }
  }

  // Helper method for UI to handle delivery confirmation
  Future<bool> confirmDeliveryCompletion(
    String requestId, 
    String verificationCode,
    {Function? onSuccess, Function? onError}
  ) async {
    try {
      final result = await completeDelivery(requestId, verificationCode);
      
      if (result) {
        if (onSuccess != null) onSuccess();
        return true;
      } else {
        if (onError != null) onError();
        return false;
      }
    } catch (e) {
      print('Error in delivery confirmation: $e');
      if (onError != null) onError();
      return false;
    }
  }

  // Wallet methods
  Future<void> updateWalletBalance(String userId, double amount) async {
    try {
      // Get current balance
      final doc = await _firestore.collection('users').doc(userId).get();
      final currentBalance = (doc.data()?['walletBalance'] ?? 0.0).toDouble();

      // Update balance
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': currentBalance + amount,
      });

      // Add transaction record
      await _firestore.collection('transactions').add({
        'userId': userId,
        'amount': amount,
        'type': amount > 0 ? 'credit' : 'debit',
        'description': amount > 0 ? 'Delivery earnings' : 'Withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating wallet balance: $e');
    }
  }
  
  // Method to fix/update missing fields for existing users
  Future<void> updateUserFields(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        print('User document not found');
        return;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      Map<String, dynamic> updates = {};
      
      // Check for missing fields and add them if needed
      if (!userData.containsKey('deliveriesMade')) {
        // If user has ratings, set deliveriesMade to match the ratings count
        if (userData.containsKey('ratings') && userData['ratings'] is List) {
          updates['deliveriesMade'] = (userData['ratings'] as List).length;
        } else {
          updates['deliveriesMade'] = 0;
        }
      }
      
      if (!userData.containsKey('ordersPlaced')) {
        updates['ordersPlaced'] = 0;
      }
      
      if (!userData.containsKey('ordersCompleted')) {
        updates['ordersCompleted'] = 0;
      }
      
      // Only update if there are missing fields
      if (updates.isNotEmpty) {
        print('Updating missing user fields: $updates');
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      print('Error updating user fields: $e');
    }
  }
}