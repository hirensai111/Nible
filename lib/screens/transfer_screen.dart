import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import '../services/stripe_service.dart';
import '../services/auth_service.dart';
import '../services/friend_transfer_service.dart';
import 'dart:ui';

class TransferScreen extends StatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  _TransferScreenState createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _friendEmailController = TextEditingController();
  final _stripeService = StripeService();
  final _authService = AuthService();
  final _friendTransferService = FriendTransferService();

  // Track both earnings and credits
  double _availableCredits = 0.0;
  double _availableEarnings = 0.0;
  bool hasDeliveryAccess = false;

  bool _isLoading = true;
  bool _isPremiumUser = false;

  // Track the selected transfer type
  String _transferType = 'transfer_to_friend';

  // Fee for internal transfers
  final double _transferFee = 0.75;

  // No fee for friend transfers (premium feature benefit)
  final double _friendTransferFee = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Add a listener to the amount controller to update the UI
    _amountController.addListener(() {
      setState(() {
        // Force UI update when text changes to update fee breakdown
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _friendEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be logged in');
      }

      // Fetch user data to get wallet information
      Map<String, dynamic>? userData = await _authService.getUserData();

      // Check if user is premium
      final isPremium = await _friendTransferService.isPremiumUser();

      setState(() {
        _availableCredits = userData?['credits'] ?? 0.0;
        _availableEarnings = userData?['earnings'] ?? 0.0;
        hasDeliveryAccess = userData?['deliveryAccess'] ?? false;
        _isPremiumUser = isPremium;

        // Set default transfer type based on delivery access
        if (!hasDeliveryAccess) {
          _transferType = 'transfer_to_friend';
        } else {
          _transferType = 'credits_to_earnings';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processTransfer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hide keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      // Show a loading dialog with Nible design
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: AppColors1.cardColor.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: AppColors1.borderGreen, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors1.primaryGreen),
                      const SizedBox(height: 20),
                      Text(
                        'Processing transfer...',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );

      // Process different transfer types
      Map<String, dynamic> result;

      if (_transferType == 'transfer_to_friend') {
        result = await _friendTransferService.transferToFriend(
          friendEmail: _friendEmailController.text,
          amount: amount,
          fee: _friendTransferFee,
        );
      } else if (_transferType == 'earnings_to_credits') {
        result = await _stripeService.transferBetweenAccounts(
          fromAccount: 'earnings',
          toAccount: 'credits',
          amount: amount,
          fee: _transferFee,
        );
      } else {
        result = await _stripeService.transferBetweenAccounts(
          fromAccount: 'credits',
          toAccount: 'earnings',
          amount: amount,
          fee: _transferFee,
        );
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor:
              result['success'] ? AppColors1.primaryGreen : Colors.red,
        ),
      );

      if (result['success']) {
        await _loadUserData();
        _amountController.clear();
        _friendEmailController.clear();
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Get the applicable fee based on transfer type
  double get _applicableFee {
    return _transferType == 'transfer_to_friend'
        ? _friendTransferFee
        : _transferFee;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      resizeToAvoidBottomInset: true,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: AppColors1.primaryGreen,
                ),
              )
              : GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 30,
                      ),
                      children: [
                        const SizedBox(height: 40),

                        // Header with back button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transfer',
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors1.iconBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors1.borderGreen.withOpacity(
                                      0.3,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: AppColors1.primaryGreen,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Balance Card with gradient
                        if (hasDeliveryAccess) ...[
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors1.deliveryCardGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors1.borderGreen,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors1.glowGreen,
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(25),
                                  child: Row(
                                    children: [
                                      // Credits section
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Credits',
                                              style: TextStyle(
                                                color: AppColors1.textSecondary,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '\$${_availableCredits.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: AppColors1.textPrimary,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Divider
                                      Container(
                                        height: 60,
                                        width: 1,
                                        color: AppColors1.borderGreen,
                                      ),
                                      // Earnings section
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Earnings',
                                              style: TextStyle(
                                                color: AppColors1.textSecondary,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '\$${_availableEarnings.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: AppColors1.textPrimary,
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Credits-only card for non-delivery users
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors1.deliveryCardGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors1.borderGreen,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors1.glowGreen,
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Available Credits',
                                        style: TextStyle(
                                          color: AppColors1.textSecondary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '\$${_availableCredits.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: AppColors1.textPrimary,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        // Transfer Type Section
                        if (hasDeliveryAccess) ...[
                          const Text(
                            'Transfer Type',
                            style: TextStyle(
                              color: AppColors1.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors1.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors1.borderGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildTransferOption(
                                  title: 'Earnings to Credits',
                                  subtitle: 'Transfer fee: \$$_transferFee',
                                  value: 'earnings_to_credits',
                                  icon: Icons.arrow_forward,
                                ),
                                _buildDivider(),
                                _buildTransferOption(
                                  title: 'Credits to Earnings',
                                  subtitle: 'Transfer fee: \$$_transferFee',
                                  value: 'credits_to_earnings',
                                  icon: Icons.arrow_back,
                                ),
                                if (_isPremiumUser) ...[
                                  _buildDivider(),
                                  _buildTransferOption(
                                    title: 'Send to Friend',
                                    subtitle: 'No fee • Premium benefit',
                                    value: 'transfer_to_friend',
                                    icon: Icons.card_giftcard,
                                    isPremium: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ] else ...[
                          if (_isPremiumUser) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors1.primaryGreen.withOpacity(0.1),
                                    AppColors1.primaryGreen.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors1.borderGreen,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors1.iconBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.card_giftcard,
                                      color: AppColors1.primaryGreen,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Send Credits to Friends',
                                          style: TextStyle(
                                            color: AppColors1.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Premium Feature • No Transfer Fee',
                                          style: TextStyle(
                                            color: AppColors1.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors1.cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors1.borderGreen.withOpacity(
                                    0.3,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    color: AppColors1.primaryGreen,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Transfer to Friends',
                                    style: TextStyle(
                                      color: AppColors1.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upgrade to premium to send credits to friends with no fees!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors1.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],

                        // Email Input Field
                        if (_transferType == 'transfer_to_friend') ...[
                          const SizedBox(height: 30),
                          const Text(
                            'Friend\'s Email',
                            style: TextStyle(
                              color: AppColors1.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors1.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors1.borderGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: TextFormField(
                              controller: _friendEmailController,
                              style: const TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter friend's email",
                                hintStyle: TextStyle(
                                  color: AppColors1.textTertiary.withOpacity(
                                    0.5,
                                  ),
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: AppColors1.primaryGreen,
                                  size: 20,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (_transferType == 'transfer_to_friend') {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an email';
                                  }
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  if (value ==
                                      FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.email) {
                                    return 'You cannot transfer to yourself';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],

                        // Amount and transfer sections
                        if (_isPremiumUser || hasDeliveryAccess) ...[
                          const SizedBox(height: 30),

                          // Amount Section
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: AppColors1.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors1.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors1.borderGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: TextFormField(
                                controller: _amountController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors1.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "\$0.00",
                                  hintStyle: TextStyle(
                                    color: AppColors1.textSubtle,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  prefixText: "\$",
                                  prefixStyle: TextStyle(
                                    color: AppColors1.primaryGreen,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {});
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter an amount';
                                  }

                                  final amount = double.tryParse(value);
                                  if (amount == null) {
                                    return 'Please enter a valid number';
                                  }

                                  if (amount <= 0) {
                                    return 'Amount must be greater than 0';
                                  }

                                  if (_transferType == 'earnings_to_credits') {
                                    if (amount > _availableEarnings) {
                                      return 'Insufficient earnings';
                                    }
                                  } else if (_transferType ==
                                          'credits_to_earnings' ||
                                      _transferType == 'transfer_to_friend') {
                                    if (amount > _availableCredits) {
                                      return 'Insufficient credits';
                                    }
                                  }

                                  if (_transferType != 'transfer_to_friend' &&
                                      amount <= _transferFee) {
                                    return 'Amount must be greater than the fee ($_transferFee)';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Fee Breakdown
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors1.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors1.borderGreen.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Summary',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Builder(
                                  builder: (context) {
                                    final enteredAmount =
                                        double.tryParse(
                                          _amountController.text,
                                        ) ??
                                        0.0;
                                    final transferredAmount =
                                        enteredAmount > _applicableFee
                                            ? enteredAmount - _applicableFee
                                            : enteredAmount;

                                    return Column(
                                      children: [
                                        _buildSummaryRow(
                                          'Amount:',
                                          '\$${enteredAmount.toStringAsFixed(2)}',
                                        ),
                                        const SizedBox(height: 12),
                                        if (_transferType !=
                                            'transfer_to_friend')
                                          _buildSummaryRow(
                                            'Transfer Fee:',
                                            '-\$$_transferFee',
                                            valueColor: Colors.red,
                                          )
                                        else
                                          _buildSummaryRow(
                                            'Premium Benefit:',
                                            'No Fee',
                                            valueColor: AppColors1.primaryGreen,
                                          ),
                                        const SizedBox(height: 12),
                                        Divider(
                                          color: AppColors1.borderGreen
                                              .withOpacity(0.3),
                                          thickness: 1,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildSummaryRow(
                                          _transferType == 'transfer_to_friend'
                                              ? 'Friend Receives:'
                                              : 'You\'ll Receive:',
                                          '\$${transferredAmount.toStringAsFixed(2)}',
                                          isTotal: true,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Transfer Button
                          Container(
                            height: 55,
                            decoration: BoxDecoration(
                              color: AppColors1.primaryGreen,
                              borderRadius: BorderRadius.circular(27),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors1.glowGreen,
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(27),
                                onTap: _processTransfer,
                                child: const Center(
                                  child: Text(
                                    'Transfer',
                                    style: TextStyle(
                                      color: AppColors1.backgroundColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildTransferOption({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    bool isPremium = false,
  }) {
    final bool isSelected = value == _transferType;

    return InkWell(
      onTap: () {
        setState(() {
          _transferType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors1.primaryGreen.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected
                          ? AppColors1.primaryGreen
                          : AppColors1.textTertiary,
                  width: 2,
                ),
                color:
                    isSelected ? AppColors1.primaryGreen : Colors.transparent,
              ),
              child:
                  isSelected
                      ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors1.backgroundColor,
                          ),
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 16),
            Icon(
              icon,
              color:
                  isSelected
                      ? AppColors1.primaryGreen
                      : AppColors1.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color:
                          isPremium
                              ? AppColors1.primaryGreen
                              : AppColors1.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors1.borderGreen.withOpacity(0.2),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors1.primaryGreen : AppColors1.textSecondary,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color:
                valueColor ??
                (isTotal ? AppColors1.primaryGreen : AppColors1.textPrimary),
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
