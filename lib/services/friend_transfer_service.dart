import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class FriendTransferService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid uuid = Uuid();

  // Get current user
  User get _currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in');
    return user;
  }

  // Check if user has premium subscription
  Future<bool> isPremiumUser() async {
    try {
      final userRef = _firestore.collection('users').doc(_currentUser.uid);
      final userData = await userRef.get();

      if (!userData.exists) return false;

      final data = userData.data() as Map<String, dynamic>;
      final subscriptionStatus = data['subscriptionStatus'] as String? ?? '';

      // Check only if subscription is active - include all paid tiers
      return subscriptionStatus == 'active';
    } catch (e) {
      print('Error checking premium status: $e');
      return false;
    }
  }

  // Find a user by email
  Future<DocumentSnapshot?> findUserByEmail(String email) async {
    try {
      final result =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (result.docs.isEmpty) return null;

      return result.docs.first;
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  // Transfer credits to friend by email with no fee
  Future<Map<String, dynamic>> transferToFriend({
    required String friendEmail,
    required double amount,
    required double fee, // Fee parameter kept for compatibility, but ignored
  }) async {
    try {
      // Always use 0 fee for friend transfers regardless of what was passed
      final actualFee = 0.0;

      final isPremium = await isPremiumUser();
      if (!isPremium) {
        throw Exception('This feature is only available for premium users');
      }

      // No minimum amount check related to fee since there is no fee
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      final friendDoc = await findUserByEmail(friendEmail);
      if (friendDoc == null) {
        throw Exception('User with that email does not exist');
      }

      final friendUid = friendDoc.id;
      if (friendUid == _currentUser.uid) {
        throw Exception('You cannot transfer credits to yourself');
      }

      final userRef = _firestore.collection('users').doc(_currentUser.uid);
      final userData = await userRef.get();

      if (!userData.exists) throw Exception('User data not found');

      final data = userData.data() as Map<String, dynamic>;
      final currentCredits = data['credits'] as num? ?? 0.0;
      if (currentCredits < amount) {
        throw Exception('Insufficient credits');
      }

      // Since fee is 0, the full amount is transferred
      final transferAmount = amount;
      final now = DateTime.now();
      final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(now);
      final friendData = friendDoc.data() as Map<String, dynamic>?;
      final friendName = friendData?['name'] as String? ?? 'Friend';
      final senderName = data['name'] as String? ?? 'Friend';

      // Generate unique IDs for transactions
      final sourceTransaction = {
        'id': uuid.v4(),
        'amount': -amount,
        'type': 'debit',
        'label': 'Transfer to $friendName ($friendEmail)',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };

      // No fee transaction since there's no fee
      // Only create a recipient transaction
      final recipientTransaction = {
        'id': uuid.v4(),
        'amount': transferAmount,
        'type': 'credit',
        'label': 'Received from $senderName (${_currentUser.email})',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };

      // Update both users in a batch
      final batch = _firestore.batch();

      batch.update(userRef, {
        'credits': FieldValue.increment(-amount),
        'transactions': FieldValue.arrayUnion([sourceTransaction]),
      });

      final friendRef = _firestore.collection('users').doc(friendUid);
      batch.update(friendRef, {
        'credits': FieldValue.increment(transferAmount),
        'transactions': FieldValue.arrayUnion([recipientTransaction]),
      });

      await batch.commit();

      return {
        'success': true,
        'message':
            'Successfully transferred \$${transferAmount.toStringAsFixed(2)} to $friendName. No fee was charged as a premium benefit.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Transfer failed: ${e.toString()}'};
    }
  }
}
