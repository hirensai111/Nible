import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // 🆕 NEW: Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Stream to track auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Create new user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'name': name,
      'email': email,
      'deliveryAccess': false, // 🔄 NEW: Default to false - admin must enable
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // Sign out
  Future<void> signOut() async {
    return await _auth.signOut();
  }

  // 🔄 UPDATED: Get user data including computed earnings and credits
  Future<Map<String, dynamic>?> getUserData() async {
    if (currentUser == null) return null;

    final uid = currentUser!.uid;

    // Fetch user profile data
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;

    // Fetch transactions
    final txnSnapshot =
        await _firestore
            .collection('transactions')
            .where('userId', isEqualTo: uid)
            .get();

    double earnings = 0.0;
    double credits = 0.0;
    List<Map<String, dynamic>> transactions = [];

    for (var doc in txnSnapshot.docs) {
      final txn = doc.data();

      final label = txn['label'] ?? '';
      final amount = (txn['amount'] ?? 0).toDouble();
      final type = txn['type'];

      if (type == 'credit' && label.toString().contains('Delivery Earnings')) {
        earnings += amount;
      }

      if (type == 'credit' &&
          label.toString().contains('Added funds to wallet')) {
        credits += amount;
      }

      transactions.add({
        'label': label,
        'timestamp': txn['timestamp'],
        'amount': amount,
        'type': type,
        'date': txn['date'],
      });
    }

    return {
      'uid': uid,
      'earnings': earnings,
      'credits': credits,
      'transactions': transactions,
      'deliveryAccess':
          userData?['deliveryAccess'] ??
          false, // Include delivery access status
      ...?userData,
    };
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String name,
    required String phone,
  }) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'name': name,
              'phone': phone,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        throw Exception('No user is currently signed in');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // 🆕 NEW: Check if user has delivery access
  Future<bool> hasDeliveryAccess() async {
    if (currentUser == null) return false;

    final userDoc =
        await _firestore.collection('users').doc(currentUser!.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>?;

    return userData?['deliveryAccess'] ?? false;
  }

  // 🆕 NEW: Admin function to grant/revoke delivery access
  Future<void> updateDeliveryAccess(String userId, bool hasAccess) async {
    await _firestore.collection('users').doc(userId).update({
      'deliveryAccess': hasAccess,
      'deliveryAccessUpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}
