import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _selectedTier;
  bool _isProcessing = false;
  static const double UPGRADE_FEE = 0.99;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? userData = await _authService.getUserData();
      setState(() {
        _userData = userData;
      });
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getCurrentTierName() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return 'Campus Access';
      case 'delivery_plus':
        return 'Delivery Plus';
      case 'all_access':
        return 'All Access';
      default:
        return 'Free Plan';
    }
  }

  String _getCurrentTierDescription() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return 'Exclusive In-App Features';
      case 'delivery_plus':
        return 'Every 8th order free';
      case 'all_access':
        return 'Every 5th order free';
      default:
        return '\$3.00 per delivery';
    }
  }

  double _getTierPrice(String tierKey) {
    switch (tierKey) {
      case 'campus_access':
        return 6.99;
      case 'delivery_plus':
        return 9.99;
      case 'all_access':
        return 12.99;
      default:
        return 0.0;
    }
  }

  String _getTierDisplayName(String tierKey) {
    switch (tierKey) {
      case 'campus_access':
        return 'Campus Access';
      case 'delivery_plus':
        return 'Delivery Plus';
      case 'all_access':
        return 'All Access';
      default:
        return 'Free Plan';
    }
  }

  bool _isUpgrade(String newTier) {
    final currentTier =
        (_userData?['subscriptionTier'] ?? 'free').toLowerCase();
    if (currentTier == 'free') return true;

    final currentPrice = _getTierPrice(currentTier);
    final newPrice = _getTierPrice(newTier);
    return newPrice > currentPrice;
  }

  bool _isDowngrade(String newTier) {
    final currentTier =
        (_userData?['subscriptionTier'] ?? 'free').toLowerCase();
    if (currentTier == 'free') return false;

    final currentPrice = _getTierPrice(currentTier);
    final newPrice = _getTierPrice(newTier);
    return newPrice < currentPrice;
  }

  double _getActualPrice(String newTier) {
    const tierPrices = {
      'free': 0.00,
      'campus_access': 6.99,
      'delivery_plus': 9.99,
      'all_access': 12.99,
    };

    final currentTierRaw = _userData?['subscriptionTier'];
    final currentTier = (currentTierRaw ?? 'free').toLowerCase();

    final currentPrice = tierPrices[currentTier] ?? 0.0;
    final newPrice = tierPrices[newTier] ?? 0.0;

    if (currentTier == newTier) return 0.0;

    // If user is on free plan, charge full price for any paid tier (no upgrade fee)
    if (currentTier == 'free') {
      return newPrice;
    }

    // For existing subscribers upgrading to a higher tier: charge difference + fee
    // For existing subscribers downgrading: charge nothing (free)
    return newPrice > currentPrice
        ? (newPrice - currentPrice + UPGRADE_FEE)
        : 0.0; // No fee for downgrades
  }

  int _getOrdersThisMonth() {
    final transactions = _userData?['transactions'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    return transactions.where((txn) {
      if (txn['type'] != 'debit') return false;
      final dateStr = txn['date'] as String?;
      if (dateStr == null) return false;

      try {
        final txnDate = DateTime.parse(dateStr);
        return txnDate.isAfter(currentMonth);
      } catch (e) {
        return false;
      }
    }).length;
  }

  double _getSpentThisMonth() {
    final transactions = _userData?['transactions'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    double total = 0.0;

    for (final txn in transactions) {
      if (txn['type'] != 'debit') continue;
      final dateStr = txn['date'] as String?;
      if (dateStr == null) continue;

      try {
        final txnDate = DateTime.parse(dateStr);
        if (txnDate.isAfter(currentMonth)) {
          final amount = (txn['amount'] as num?)?.abs() ?? 0.0;
          total += amount;
        }
      } catch (e) {
        continue;
      }
    }

    return total;
  }

  Future<void> _showPaymentMethodDialog() async {
    final credits = _userData?['credits'] ?? 0.0;
    final earnings = _userData?['earnings'] ?? 0.0;
    final price = _getActualPrice(_selectedTier!);
    final currentTier = _userData?['subscriptionTier'];

    String transactionLabel =
        'Subscription: ${_getTierDisplayName(_selectedTier!)}';

    if (currentTier != null && currentTier != 'free') {
      if (_isUpgrade(_selectedTier!)) {
        transactionLabel = 'Upgrade to ${_getTierDisplayName(_selectedTier!)}';
      } else if (_isDowngrade(_selectedTier!)) {
        transactionLabel = 'Switch to ${_getTierDisplayName(_selectedTier!)}';
      }
    }

    if (credits < price && earnings < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient funds. You need \$${price.toStringAsFixed(2)} but have \$${credits.toStringAsFixed(2)} credits and \$${earnings.toStringAsFixed(2)} earnings.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? selectedPaymentMethod = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors1.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Payment Method',
                  style: TextStyle(
                    color: AppColors1.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  transactionLabel,
                  style: TextStyle(
                    color: AppColors1.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: \$${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: AppColors1.primaryGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                // Credits option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors1.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: AppColors1.primaryGreen,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Credits',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Balance: \$${credits.toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          credits >= price
                              ? AppColors1.primaryGreen
                              : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  enabled: credits >= price,
                  onTap:
                      credits >= price
                          ? () => Navigator.pop(context, 'credits')
                          : null,
                  tileColor:
                      credits >= price
                          ? Colors.transparent
                          : AppColors1.iconBackgroundColor.withOpacity(0.1),
                ),
                const SizedBox(height: 12),
                // Earnings option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors1.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.monetization_on,
                      color: AppColors1.primaryGreen,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Earnings',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Balance: \$${earnings.toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          earnings >= price
                              ? AppColors1.primaryGreen
                              : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  enabled: earnings >= price,
                  onTap:
                      earnings >= price
                          ? () => Navigator.pop(context, 'earnings')
                          : null,
                  tileColor:
                      earnings >= price
                          ? Colors.transparent
                          : AppColors1.iconBackgroundColor.withOpacity(0.1),
                ),
                const SizedBox(height: 20),
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors1.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    if (selectedPaymentMethod != null) {
      await _processSubscription(selectedPaymentMethod);
    }
  }

  Future<void> _processSubscription(String paymentMethod) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final price = _getActualPrice(_selectedTier!);
      final currentTier = _userData?['subscriptionTier'];
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data()!;

        final currentBalance =
            paymentMethod == 'credits'
                ? userData['credits'] ?? 0.0
                : userData['earnings'] ?? 0.0;

        if (currentBalance < price) {
          throw Exception('Insufficient ${paymentMethod}');
        }

        final newBalance = currentBalance - price;
        final now = DateTime.now();

        DateTime subscriptionEndDate;
        if (currentTier != null &&
            currentTier != 'free' &&
            userData['subscriptionEndDate'] != null) {
          subscriptionEndDate =
              (userData['subscriptionEndDate'] as Timestamp).toDate();
        } else {
          subscriptionEndDate = DateTime(now.year, now.month + 1, now.day);
        }

        String transactionType = 'subscription';
        String transactionLabel =
            'Subscription: ${_getTierDisplayName(_selectedTier!)}';

        if (currentTier != null && currentTier != 'free') {
          if (_isUpgrade(_selectedTier!)) {
            transactionType = 'upgrade';
            transactionLabel =
                'Upgrade to ${_getTierDisplayName(_selectedTier!)}';
          } else if (_isDowngrade(_selectedTier!)) {
            transactionType = 'downgrade';
            transactionLabel =
                'Switch to ${_getTierDisplayName(_selectedTier!)}';
          }
        }

        final transactionRecord = {
          'amount': -price,
          'date': now.toIso8601String(),
          'label': transactionLabel,
          'timestamp': now.toIso8601String(),
          'type': transactionType,
        };

        final currentTransactions = List<Map<String, dynamic>>.from(
          userData['transactions'] ?? [],
        );
        currentTransactions.insert(0, transactionRecord);

        final updateData = {
          paymentMethod: newBalance,
          'subscriptionTier': _selectedTier,
          'subscriptionStatus': 'active',
          'subscriptionStartDate': FieldValue.serverTimestamp(),
          'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
          'transactions': currentTransactions,
        };

        if (_selectedTier != null) {
          updateData['subscriptionUsage'] = {
            'ordersThisMonth': 0,
            'freeOrdersUsed': 0,
            'freeOrdersRemaining': _selectedTier == 'all_access' ? 3 : 0,
            'lastResetDate': FieldValue.serverTimestamp(),
          };
        }

        transaction.update(userRef, updateData);
      });

      String successMessage =
          'Successfully subscribed to ${_getTierDisplayName(_selectedTier!)}!';
      if (currentTier != null && currentTier != 'free') {
        if (_isUpgrade(_selectedTier!)) {
          successMessage =
              'Successfully upgraded to ${_getTierDisplayName(_selectedTier!)}!';
        } else if (_isDowngrade(_selectedTier!)) {
          successMessage =
              'Successfully switched to ${_getTierDisplayName(_selectedTier!)}!';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedTier = null;
      });
      await _loadUserData();
    } catch (e) {
      print('Error processing subscription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process subscription: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Add this method to your _SubscriptionScreenState class
  Future<void> _showCancelConfirmationDialog() async {
  final currentTier = _userData?['subscriptionTier'];
  final subscriptionEndDate =
      _userData?['subscriptionEndDate'] != null
          ? (_userData?['subscriptionEndDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30));

  final formattedEndDate =
      "${subscriptionEndDate.month}/${subscriptionEndDate.day}/${subscriptionEndDate.year}";

  bool? shouldCancel = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors1.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors1.borderGreen, width: 1),
      ),
      title: Text(
        'Cancel Subscription?',
        style: TextStyle(
          color: AppColors1.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your ${_getTierDisplayName(currentTier ?? 'free')} plan will remain active until $formattedEndDate.',
            style: TextStyle(color: AppColors1.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            'After this date, your subscription will end and you will be moved to the Free Plan.',
            style: TextStyle(color: AppColors1.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Keep Subscription',
            style: TextStyle(color: AppColors1.textTertiary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors1.cancelButtonGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  if (shouldCancel == true) {
    await _cancelSubscription();
  }
}


  // Add this method to handle the actual cancellation
  Future<void> _cancelSubscription() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data()!;

        // Keep the subscription end date as is, but mark status as 'canceled'
        transaction.update(userRef, {
          'subscriptionStatus': 'canceled',
          // Add a flag to indicate it's been canceled but still active
          'subscriptionCanceled': true,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription successfully canceled'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadUserData();
    } catch (e) {
      print('Error canceling subscription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel subscription: ${e.toString()}'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _showReactivateDialog() async {
    final subscriptionEndDate =
        _userData?['subscriptionEndDate'] != null
            ? (_userData?['subscriptionEndDate'] as Timestamp).toDate()
            : null;
    final formattedEndDate =
        subscriptionEndDate != null
            ? "${subscriptionEndDate.month}/${subscriptionEndDate.day}/${subscriptionEndDate.year}"
            : "N/A";

    final currentTier = _userData?['subscriptionTier'];
    final currentTierName = _getTierDisplayName(currentTier ?? 'free');

    bool? shouldReactivate = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D0A05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0x1FD4641F), width: 1),
            ),
            title: const Text(
              'Reactivate Subscription?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your $currentTierName plan is currently set to expire on $formattedEndDate.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'By reactivating your subscription, your current plan will continue and automatically renew at the end of the billing period.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'After reactivation, you can switch plans if desired.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors1.deliveryCardGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'Reactivate',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldReactivate == true) {
      await _reactivateSubscription();
    }
  }

  Future<void> _reactivateSubscription() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final userData = userDoc.data()!;

        // Remove the canceled flags and set status back to active
        transaction.update(userRef, {
          'subscriptionStatus': 'active',
          'subscriptionCanceled': false,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription successfully reactivated'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadUserData();
    } catch (e) {
      print('Error reactivating subscription: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reactivate subscription: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Widget _buildCurrentPlanCard() {
    final isFreePlan =
        _userData?['subscriptionTier'] == null ||
        _userData?['subscriptionTier'] == 'free';
    final isCanceled = _userData?['subscriptionCanceled'] == true;
    final ordersThisMonth = _getOrdersThisMonth();
    final spentThisMonth = _getSpentThisMonth();

    final subscriptionEndDate =
        _userData?['subscriptionEndDate'] != null
            ? (_userData?['subscriptionEndDate'] as Timestamp).toDate()
            : null;
    final formattedEndDate =
        subscriptionEndDate != null
            ? "${subscriptionEndDate.month}/${subscriptionEndDate.day}/${subscriptionEndDate.year}"
            : "N/A";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors1.deliveryCardGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors1.textPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: TextStyle(
                        color: AppColors1.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _getCurrentTierName(),
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isCanceled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Canceled',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isCanceled) ...[
            Text(
              'Your plan will remain active until $formattedEndDate',
              style: TextStyle(
                color: AppColors1.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Text(
              _getCurrentTierDescription(),
              style: TextStyle(color: AppColors1.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          // Usage statistics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors1.iconBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors1.borderGreen, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'This Month',
                        style: TextStyle(
                          color: AppColors1.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$ordersThisMonth',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'orders',
                        style: TextStyle(
                          color: AppColors1.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors1.borderGreen),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Total Spent',
                        style: TextStyle(
                          color: AppColors1.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${spentThisMonth.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'this month',
                        style: TextStyle(
                          color: AppColors1.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isFreePlan) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors1.progressGradient.take(3).toList(),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors1.borderGreen, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors1.glowGreen,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '💡 Ready to upgrade? Save on every order!',
                style: TextStyle(
                  color: AppColors1.backgroundColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (!isFreePlan) ...[
            const SizedBox(height: 16),
            isCanceled
                ? TextButton(
                  onPressed: _showReactivateDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: AppColors1.primaryGreen.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppColors1.primaryGreen.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: AppColors1.primaryGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reactivate Subscription',
                        style: TextStyle(
                          color: AppColors1.primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                : TextButton(
                  onPressed: _showCancelConfirmationDialog,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        color: AppColors1.textTertiary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cancel Subscription',
                        style: TextStyle(
                          color: AppColors1.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionTierCard({
    required String tierKey,
    required String tierName,
    required double price,
    required String description,
    required List<String> features,
    required IconData icon,
    bool isPopular = false,
  }) {
    final currentTier = _userData?['subscriptionTier'];
    final isCurrentPlan = currentTier == tierKey;
    final isCanceled = _userData?['subscriptionCanceled'] == true;

    return Container(
      margin: EdgeInsets.only(top: isPopular ? 12 : 0),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? AppColors1.primaryGreen : AppColors1.borderGreen,
          width: isPopular ? 2 : 1,
        ),
        boxShadow:
            isPopular
                ? [
                  BoxShadow(
                    color: AppColors1.glowGreen,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isPopular)
            Positioned(
              top: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors1.primaryGreen,
                        AppColors1.primaryGreen.withOpacity(0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(color: AppColors1.glowGreen, blurRadius: 10),
                    ],
                  ),
                  child: Text(
                    'POPULAR',
                    style: TextStyle(
                      color: AppColors1.backgroundColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular) const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors1.iconBackgroundColor,
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color: AppColors1.borderGreen,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors1.primaryGreen,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SubscriptionTierHeader(
                            title: tierName,
                            showTooltip: tierKey == 'campus_access',
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: TextStyle(
                              color: AppColors1.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isCanceled) ...[
                          Text(
                            '\$0.00',
                            style: TextStyle(
                              color: AppColors1.textSubtle,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '/month',
                            style: TextStyle(
                              color: AppColors1.textSubtle,
                              fontSize: 10,
                            ),
                          ),
                        ] else ...[
                          Text(
                            isCurrentPlan
                                ? '\$${price.toStringAsFixed(2)}'
                                : _isUpgrade(tierKey)
                                ? '\$${_getActualPrice(tierKey).toStringAsFixed(2)}'
                                : _isDowngrade(tierKey)
                                ? 'Free'
                                : '\$${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors1.primaryGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            isCurrentPlan
                                ? '/month'
                                : _isUpgrade(tierKey)
                                ? 'to upgrade'
                                : _isDowngrade(tierKey)
                                ? 'to downgrade'
                                : '/month',
                            style: TextStyle(
                              color: AppColors1.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  children:
                      features
                          .map(
                            (feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color:
                                          isCanceled
                                              ? AppColors1.primaryGreen
                                                  .withOpacity(0.3)
                                              : AppColors1.primaryGreen,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(7),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color:
                                          isCanceled
                                              ? Colors.white54
                                              : AppColors1.backgroundColor,
                                      size: 9,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: TextStyle(
                                        color:
                                            isCanceled
                                                ? AppColors1.textTertiary
                                                : AppColors1.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient:
                          (isCurrentPlan || isCanceled)
                              ? null
                              : LinearGradient(
                                colors: [
                                  AppColors1.primaryGreen,
                                  AppColors1.primaryGreen.withOpacity(0.8),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed:
                          isCanceled
                              ? null
                              : (isCurrentPlan)
                              ? null
                              : () {
                                setState(() {
                                  _selectedTier = tierKey;
                                });
                                _showPaymentMethodDialog();
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isCurrentPlan || isCanceled
                                ? AppColors1.iconBackgroundColor
                                : Colors.transparent,
                        disabledBackgroundColor:
                            isCanceled
                                ? AppColors1.iconBackgroundColor.withOpacity(
                                  0.4,
                                )
                                : AppColors1.iconBackgroundColor,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        isCanceled
                            ? 'Unavailable'
                            : isCurrentPlan
                            ? 'Current Plan'
                            : 'Select Plan',
                        style: TextStyle(
                          color:
                              isCanceled
                                  ? AppColors1.textSubtle
                                  : isCurrentPlan
                                  ? AppColors1.textTertiary
                                  : AppColors1.backgroundColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Replace your Scaffold in build() method with:
  @override
  Widget build(BuildContext context) {
    final isCanceled = _userData?['subscriptionCanceled'] == true;

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor, // Pure black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors1.iconBackgroundColor,
            border: Border.all(color: AppColors1.borderGreen, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors1.primaryGreen),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ),
        title: const Text(
          'Premium Plans',
          style: TextStyle(
            color: AppColors1.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: AppColors1.primaryGreen,
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Plan Status Card
                    _buildCurrentPlanCard(),
                    const SizedBox(height: 25),

                    // Subscription plans header
                    Row(
                      children: [
                        Text(
                          'Choose Your Plan',
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isCanceled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Reactivate Required',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCanceled
                          ? 'Reactivate your subscription to select a plan'
                          : 'Save money and unlock premium features',
                      style: TextStyle(
                        color: AppColors1.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Subscription tier cards - all three tiers
                    _buildSubscriptionTierCard(
                      tierKey: 'campus_access',
                      tierName: 'Campus Access',
                      price: 6.99,
                      description: 'Perfect for occasional campus dining',
                      features: [
                        'Exclusive In-App Features',
                        'Transfer Between Friends',
                        'Place Multiple Order Requests',
                      ],
                      icon: Icons.school,
                    ),
                    const SizedBox(height: 15),

                    _buildSubscriptionTierCard(
                      tierKey: 'delivery_plus',
                      tierName: 'Delivery Plus',
                      price: 9.99,
                      description: 'Most popular choice',
                      features: [
                        'All Campus Access features',
                        'Reduced delivery costs',
                        'Every 8th order free',
                        'Priority order processing',
                      ],
                      icon: Icons.flash_on,
                      isPopular: true,
                    ),
                    const SizedBox(height: 15),

                    _buildSubscriptionTierCard(
                      tierKey: 'all_access',
                      tierName: 'All Access',
                      price: 12.99,
                      description: 'Best value for heavy users (10+ orders)',
                      features: [
                        'All Delivery Plus features',
                        'Every 5th order free',
                        '3 completely free deliveries/month',
                      ],
                      icon: Icons.star,
                    ),

                    // Bottom padding
                    const SizedBox(height: 30),
                  ],
                ),
              ),
    );
  }
}

class SubscriptionTierHeader extends StatelessWidget {
  final String title;
  final bool showTooltip;

  const SubscriptionTierHeader({
    Key? key,
    required this.title,
    this.showTooltip = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showTooltip) ...[
          const SizedBox(width: 6),
          Tooltip(
            message:
                '• Off-campus students request meal plan purchases\n'
                '• On-campus students with meal plans accept and pay using dining dollars\n'
                '• Off-campus students pay order value + app fee through wallet system\n'
                '• Both parties save money (50% dining discount minus small service fee)',
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 11),
            child: const Icon(
              Icons.help_outline,
              color: Colors.white70,
              size: 16,
            ),
          ),
        ],
      ],
    );
  }
}
