import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a new pickup order with sequential document ID
  /// Returns the order details for navigation to confirmation screen
  Future<OrderResult> createPickupOrder({
    required String diningHall,
    required String deliveryLocation,
    required double totalFee,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (deliveryLocation.trim().isEmpty) {
      throw Exception('Delivery location cannot be empty');
    }

    // Generate next order ID using transaction
    return await _firestore.runTransaction<OrderResult>((transaction) async {
      // PHASE 1: PERFORM ALL READS FIRST

      // Get counter document
      final counterRef = _firestore.collection('requests').doc('counter');
      final counterSnapshot = await transaction.get(counterRef);

      // Get user document
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userSnapshot = await transaction.get(userDocRef);

      // PHASE 2: PROCESS READ RESULTS

      // Process counter
      int nextOrderNumber;
      if (!counterSnapshot.exists) {
        nextOrderNumber = 1;
      } else {
        final currentCount = counterSnapshot.data()?['currentCount'] ?? 0;
        nextOrderNumber = currentCount + 1;

        // Check if we've reached the limit
        if (nextOrderNumber > 100000) {
          throw Exception('Order limit reached. Contact support.');
        }
      }

      // Format order ID with 5-digit padding
      final orderId = 'Nib-${nextOrderNumber.toString().padLeft(5, '0')}';

      // Process user data
      if (!userSnapshot.exists) {
        throw Exception('User profile not found');
      }

      final currentCredits = (userSnapshot.data()?['credits'] ?? 0).toDouble();
      if (currentCredits < totalFee) {
        throw Exception('Insufficient credits. Please add funds.');
      }

      // PHASE 3: PERFORM ALL WRITES

      // Update or create counter
      if (!counterSnapshot.exists) {
        transaction.set(counterRef, {'currentCount': nextOrderNumber});
      } else {
        transaction.update(counterRef, {'currentCount': nextOrderNumber});
      }

      // Create order document with custom ID
      final orderRef = _firestore.collection('requests').doc(orderId);
      transaction.set(orderRef, {
        'userId': user.uid,
        'diningHall': diningHall,
        'dropOff': deliveryLocation.trim(),
        'totalFee': totalFee,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'orderNumber': orderId, // Same as document ID
      });

      // Update user account
      transaction.update(userDocRef, {
        'credits': currentCredits - totalFee,
        'transactions': FieldValue.arrayUnion([
          {
            'label': 'Pickup Request ($orderId)',
            'amount': -totalFee,
            'type': 'debit',
            'timestamp': DateTime.now().toIso8601String(),
            'date': DateTime.now().toIso8601String(),
          },
        ]),
        'subscriptionUsage.ordersThisMonth': FieldValue.increment(1),
        'ordersPlaced': FieldValue.increment(1),
      });

      return OrderResult(
        orderId: orderId,
        diningHall: diningHall,
        deliveryLocation: deliveryLocation.trim(),
        totalFee: totalFee,
      );
    });
  }

  /// Gets the current order count (for analytics/admin purposes)
  Future<int> getCurrentOrderCount() async {
    try {
      final counterDoc =
          await _firestore.collection('requests').doc('counter').get();

      return counterDoc.data()?['currentCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Gets an order by ID (useful for order tracking)
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final orderDoc =
          await _firestore.collection('requests').doc(orderId).get();

      return orderDoc.exists ? orderDoc.data() : null;
    } catch (e) {
      print('Error fetching order $orderId: $e');
      return null;
    }
  }

  /// Gets all orders for current user
  Future<List<Map<String, dynamic>>> getUserOrders({int? limit}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('requests')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching user orders: $e');
      return [];
    }
  }

  /// Updates order status (for admin/driver use)
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('requests').doc(orderId).update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }
}

/// Result class for order creation
class OrderResult {
  final String orderId;
  final String diningHall;
  final String deliveryLocation;
  final double totalFee;

  OrderResult({
    required this.orderId,
    required this.diningHall,
    required this.deliveryLocation,
    required this.totalFee,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'diningHall': diningHall,
      'deliveryLocation': deliveryLocation,
      'totalFee': totalFee,
    };
  }
}
