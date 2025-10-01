import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StripeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User get _currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in');
    return user;
  }

  Future<Map<String, dynamic>> makePayment({
    required String amount,
    required String currency,
    CardFieldInputDetails? cardDetails,
  }) async {
    try {
      if (cardDetails == null || !cardDetails.complete) {
        return {
          'success': false,
          'message': 'Please complete all card details',
        };
      }

      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      print('✅ Payment method created: ${paymentMethod.id}');

      await _updateUserWallet(double.parse(amount));

      return {'success': true, 'message': 'Payment successful!'};
    } catch (e) {
      return {'success': false, 'message': 'Payment failed: ${e.toString()}'};
    }
  }

  Future<void> _updateUserWallet(double amount) async {
    final userRef = _firestore.collection('users').doc(_currentUser.uid);
    final userData = await userRef.get();

    if (!userData.exists) throw Exception('User data not found');

    final currentCredits = userData.data()?['credits'] ?? 0.0;
    final now = DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(now);

    final transaction = {
      'amount': amount,
      'type': 'credit',
      'label': 'Added funds to wallet',
      'timestamp': formattedDate,
      'date': now.toIso8601String(),
    };

    await userRef.update({
      'credits': currentCredits + amount,
      'transactions': FieldValue.arrayUnion([transaction]),
    });
  }

  Future<Map<String, dynamic>> transferBetweenAccounts({
    required String fromAccount,
    required String toAccount,
    required double amount,
    required double fee,
  }) async {
    try {
      if (fromAccount == toAccount) {
        throw Exception('Source and destination accounts cannot be the same');
      }

      if (amount <= fee) {
        throw Exception('Amount must be greater than the fee');
      }

      final userRef = _firestore.collection('users').doc(_currentUser.uid);
      final userData = await userRef.get();
      if (!userData.exists) throw Exception('User data not found');

      final currentEarnings = userData.data()?['earnings'] ?? 0.0;
      final currentCredits = userData.data()?['credits'] ?? 0.0;

      if (fromAccount == 'earnings' && currentEarnings < amount) {
        throw Exception('Insufficient earnings');
      }
      if (fromAccount == 'credits' && currentCredits < amount) {
        throw Exception('Insufficient credits');
      }

      final transferAmount = amount - fee;
      final now = DateTime.now();
      final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(now);

      // Ensure type is a string
      final sourceTransaction = {
        'amount': -amount,
        'type': 'debit', // Explicitly set as string
        'label':
            'Transfer to ${toAccount[0].toUpperCase()}${toAccount.substring(1)}',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };
      final destinationTransaction = {
        'amount': transferAmount,
        'type': 'credit', // Explicitly set as string
        'label':
            'Transfer from ${fromAccount[0].toUpperCase()}${fromAccount.substring(1)}',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };
      final feeTransaction = {
        'amount': -fee,
        'type': 'fee', // Explicitly set as string
        'label': 'Transfer fee',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };

      final updates = {
        'transactions': FieldValue.arrayUnion([
          sourceTransaction,
          destinationTransaction,
          feeTransaction,
        ]),
      };

      if (fromAccount == 'earnings') {
  updates['earnings'] = FieldValue.increment(-amount);
  updates['credits'] = FieldValue.increment(transferAmount);
} else {
  updates['credits'] = FieldValue.increment(-amount);
  updates['earnings'] = FieldValue.increment(transferAmount);
}


      await userRef.update(updates);

      return {
        'success': true,
        'message':
            'Transfer successful! A fee of \$${fee.toStringAsFixed(2)} was deducted.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Transfer failed: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> processCashOut({required double amount}) async {
    try {
      final userRef = _firestore.collection('users').doc(_currentUser.uid);
      final userData = await userRef.get();
      if (!userData.exists) throw Exception('User data not found');

      final currentEarnings = userData.data()?['earnings'] ?? 0.0;
      if (currentEarnings < amount) {
        throw Exception('Insufficient funds for cash out');
      }

      final now = DateTime.now();
      final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(now);

      final transaction = {
        'amount': -amount,
        'type': 'debit',
        'label': 'Cash out request',
        'timestamp': formattedDate,
        'date': now.toIso8601String(),
      };

      await userRef.update({
        'earnings': currentEarnings - amount,
        'transactions': FieldValue.arrayUnion([transaction]),
      });

      return {
        'success': true,
        'message':
            'Cash out successful! Your funds will be transferred to your bank account.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Cash out failed: ${e.toString()}'};
    }
  }
}
