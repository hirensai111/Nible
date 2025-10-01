import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'transfer_screen.dart';
import 'card_payment_screen.dart';
import '../services/auth_service.dart';
import '../services/stripe_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  final _stripeService = StripeService();
  double earnings = 67.75;
  double credits = 78.00;
  double eligibleAmount = 67.75;
  bool hasDeliveryAccess = false;
  List<Map<String, dynamic>> transactions = [
    {
      'label': 'Pickup Request (PMH-2963)',
      'timestamp': '2025-05-18T01:25:44.653988',
      'amount': -3.00,
      'type': 'debit',
      'date': '2025-05-18',
    },
    {
      'label': 'Transfer fee',
      'timestamp': 'May 18, 2025 • 1:24 AM',
      'amount': -0.75,
      'type': 'debit',
      'date': '2025-05-18',
    },
    {
      'label': 'Transfer from Credits',
      'timestamp': 'May 18, 2025 • 1:24 AM',
      'amount': 9.25,
      'type': 'credit',
      'date': '2025-05-18',
    },
    {
      'label': 'Transfer to Earnings',
      'timestamp': 'May 18, 2025 • 1:24 AM',
      'amount': -10.00,
      'type': 'debit',
      'date': '2025-05-18',
    },
    {
      'label': 'Added funds to wallet',
      'timestamp': 'May 12, 2025 • 10:41 AM',
      'amount': 50.00,
      'type': 'credit',
      'date': '2025-05-12',
    },
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWalletData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWalletData();
    }
  }

  Future<void> _loadWalletData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? userData = await _authService.getUserData();

      if (!mounted) return;
      setState(() {
        earnings = userData?['earnings'] ?? 0.0;
        credits = userData?['credits'] ?? 0.0;
        hasDeliveryAccess = userData?['deliveryAccess'] ?? false;
        eligibleAmount = earnings >= 10.0 ? earnings : 0.0;
        transactions = List<Map<String, dynamic>>.from(
          userData?['transactions'] ?? [],
        );

        if (transactions.isNotEmpty && transactions[0]['date'] != null) {
          transactions.sort((a, b) {
            final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime(1970);
            final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });
        }
      });
    } catch (e) {
      print('Error loading wallet data: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddFundsDialog() async {
    final TextEditingController amountController = TextEditingController();
    String? errorMessage;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor:
                      AppColors1.cardColor, // Updated to Nible color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors1.borderGreen, width: 1),
                  ),
                  title: const Text(
                    'Add Funds',
                    style: TextStyle(color: AppColors1.textPrimary),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter amount to add to your wallet (minimum \$10, maximum \$1000):',
                        style: TextStyle(color: AppColors1.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: AppColors1.textTertiary),
                          prefixText: '\$',
                          prefixStyle: const TextStyle(
                            color: AppColors1.textPrimary,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors1.iconBackgroundColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors1.primaryGreen,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: errorMessage,
                          errorStyle: const TextStyle(color: Colors.red),
                          filled: true,
                          fillColor: AppColors1.iconBackgroundColor.withOpacity(
                            0.5,
                          ),
                        ),
                        style: const TextStyle(color: AppColors1.textPrimary),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors1.textTertiary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final input = amountController.text.trim();
                        double? amount = double.tryParse(input);

                        if (amount == null || amount < 10 || amount > 1000) {
                          setDialogState(() {
                            errorMessage =
                                amount == null
                                    ? 'Please enter a valid number'
                                    : amount < 10
                                    ? 'Minimum amount is \$10'
                                    : 'Maximum amount is \$1000';
                          });
                          return;
                        }

                        Navigator.of(context).pop();
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => CardPaymentScreen(amount: amount),
                          ),
                        );

                        if (result == true) {
                          await _loadWalletData();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors1.primaryGreen,
                        foregroundColor: AppColors1.backgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _handleCashOut() async {
    final TextEditingController amountController = TextEditingController();
    amountController.text = eligibleAmount.toString();
    String? errorMessage;
    double selectedAmount = eligibleAmount;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: AppColors1.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors1.borderGreen, width: 1),
                  ),
                  title: const Text(
                    'Cash Out',
                    style: TextStyle(color: AppColors1.textPrimary),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Transfer your earnings to your bank account:',
                        style: TextStyle(color: AppColors1.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: AppColors1.textTertiary),
                          prefixText: '\$',
                          prefixStyle: const TextStyle(
                            color: AppColors1.textPrimary,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors1.iconBackgroundColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors1.primaryGreen,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText: errorMessage,
                          errorStyle: const TextStyle(color: Colors.red),
                          filled: true,
                          fillColor: AppColors1.iconBackgroundColor.withOpacity(
                            0.5,
                          ),
                        ),
                        style: const TextStyle(color: AppColors1.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Minimum: \$10.00, Maximum: \$1,000.00',
                        style: TextStyle(
                          color: AppColors1.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Available for cash out: \$${eligibleAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppColors1.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors1.textTertiary),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final input = amountController.text.trim();
                        final amount = double.tryParse(input);

                        if (amount == null ||
                            amount < 10 ||
                            amount > 1000 ||
                            amount > eligibleAmount) {
                          setDialogState(() {
                            errorMessage =
                                amount == null
                                    ? 'Please enter a valid number'
                                    : amount < 10
                                    ? 'Minimum amount is \$10'
                                    : amount > 1000
                                    ? 'Maximum amount is \$1000'
                                    : 'Insufficient earnings';
                          });
                          return;
                        }

                        selectedAmount = amount;
                        Navigator.of(context).pop();

                        await _processCashOut(selectedAmount);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors1.primaryGreen,
                        foregroundColor: AppColors1.backgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Cash Out'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _processCashOut(double amount) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Dialog(
              backgroundColor: AppColors1.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors1.primaryGreen),
                    const SizedBox(height: 16),
                    const Text(
                      'Processing cash out...',
                      style: TextStyle(color: AppColors1.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
      );

      final result = await _stripeService.processCashOut(amount: amount);

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor:
                result['success'] ? AppColors1.primaryGreen : Colors.red,
          ),
        );
      }

      if (result['success'] && mounted) {
        await _loadWalletData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors1.deliveryCardGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors1.backgroundColor,
        body:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors1.primaryGreen,
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _loadWalletData,
                  color: AppColors1.primaryGreen,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Wallet',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Current Balance',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBalanceSection(),
                      if (hasDeliveryAccess) ...[
                        const SizedBox(height: 16),
                        _buildTransferButton(),
                      ],
                      const SizedBox(height: 20),

                      if (hasDeliveryAccess) ...[
                        _buildEligibilityCard(eligibleAmount),
                        const SizedBox(height: 35),
                      ] else ...[
                        const SizedBox(height: 15),
                      ],

                      _buildTransactionHistory(transactions),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    if (!hasDeliveryAccess) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors1.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors1.borderGreen, width: 1),
        ),
        child: Row(
          children: [
            // Credits Section
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Credits',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${credits.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 120,
                    height: 35,
                    child: ElevatedButton(
                      onPressed: _showAddFundsDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors1.primaryGreen,
                        foregroundColor: AppColors1.backgroundColor,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add Funds',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Transfer Section
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Transfer',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.swap_horiz,
                    color: AppColors1.primaryGreen,
                    size: 32,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 120,
                    height: 35,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TransferScreen(),
                          ),
                        );
                        await _loadWalletData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors1.iconBackgroundColor,
                        foregroundColor: AppColors1.textPrimary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Transfer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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

    // Layout for users with delivery access
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Credits Section
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Credits',
                      style: TextStyle(
                        color: AppColors1.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${credits.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors1.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 100,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: _showAddFundsDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors1.primaryGreen,
                          foregroundColor: AppColors1.backgroundColor,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Add Funds',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Separator Line
              Container(height: 90, width: 1, color: AppColors1.borderGreen),

              // Earnings Section
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Earnings',
                      style: TextStyle(
                        color: AppColors1.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${earnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors1.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 100,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: earnings >= 10.0 ? _handleCashOut : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              earnings >= 10.0
                                  ? AppColors1.primaryGreen
                                  : AppColors1.iconBackgroundColor,
                          foregroundColor:
                              earnings >= 10.0
                                  ? AppColors1.backgroundColor
                                  : AppColors1.textTertiary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cash Out',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const TransferScreen()),
          );
          await _loadWalletData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors1.iconBackgroundColor,
          foregroundColor: AppColors1.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Transfer',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEligibilityCard(double eligibleAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors1.progressGradient.take(3).toList(),
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors1.glowGreen,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Eligible for cash out: \$${eligibleAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors1.backgroundColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            eligibleAmount > 0
                ? 'You are eligible to cash out'
                : 'Minimum \$10.00 required',
            style: TextStyle(
              color: AppColors1.backgroundColor.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getTransactionIconColor(String? type) {
    switch (type) {
      case 'credit':
        return AppColors1.primaryGreen;
      case 'debit':
        return AppColors1.iconBackgroundColor;
      default:
        return AppColors1.textSubtle;
    }
  }

  Widget _buildTransactionHistory(List<Map<String, dynamic>> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction History',
          style: TextStyle(
            color: AppColors1.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors1.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors1.borderGreen, width: 1),
          ),
          child: Column(
            children:
                transactions.asMap().entries.map((entry) {
                  final txn = entry.value;
                  final isLast = entry.key == transactions.length - 1;
                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTransactionIconColor(txn['type']),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              '\$',
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                txn['label'] ?? 'Transaction',
                                style: const TextStyle(
                                  color: AppColors1.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                txn['timestamp'] ?? 'Unknown time',
                                style: TextStyle(
                                  color: AppColors1.textSubtle,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          ((txn['amount'] ?? 0) > 0 ? '+' : '') +
                              '\$${(txn['amount'] ?? 0.0).abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color:
                                (txn['amount'] ?? 0) > 0
                                    ? AppColors1.primaryGreen
                                    : AppColors1.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }
}
