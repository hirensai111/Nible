import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../constants/colors.dart';
import '../services/stripe_service.dart';
import 'dart:ui';

class CardPaymentScreen extends StatefulWidget {
  final double amount;

  const CardPaymentScreen({Key? key, required this.amount}) : super(key: key);

  @override
  _CardPaymentScreenState createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final StripeService _stripeService = StripeService();
  final CardFormEditController _controller = CardFormEditController();
  bool _isLoading = false;

  // Variables to hold card details for real-time updates
  String _cardNumber = '';
  String _expiryMonth = '';
  String _expiryYear = '';
  String _cardBrand = '';

  // Throttle updates
  DateTime? _lastUpdate;
  static const _updateThreshold = Duration(milliseconds: 100);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCardFormChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onCardFormChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onCardFormChanged() {
    // Throttle updates to reduce lag
    final now = DateTime.now();
    if (_lastUpdate != null &&
        now.difference(_lastUpdate!) < _updateThreshold) {
      return;
    }
    _lastUpdate = now;

    final details = _controller.details;
    final newCardNumber = details.number ?? '';
    final newExpiryMonth =
        details.expiryMonth?.toString().padLeft(2, '0') ?? '';
    final newExpiryYear = details.expiryYear?.toString() ?? '';
    final newCardBrand = _getCardBrand(newCardNumber);

    // Only update if values actually changed
    if (_cardNumber != _formatCardNumber(newCardNumber) ||
        _expiryMonth != newExpiryMonth ||
        _expiryYear !=
            (newExpiryYear.length >= 2 ? newExpiryYear.substring(2) : '') ||
        _cardBrand != newCardBrand) {
      setState(() {
        if (newCardNumber.isNotEmpty) {
          _cardNumber = _formatCardNumber(newCardNumber);
        } else {
          _cardNumber = '';
        }

        _expiryMonth = newExpiryMonth;
        _expiryYear =
            newExpiryYear.length >= 2 ? newExpiryYear.substring(2) : '';
        _cardBrand = newCardBrand;
      });
    }
  }

  String _formatCardNumber(String number) {
    String cleanNumber = number.replaceAll(' ', '');
    if (cleanNumber.isEmpty) return '';

    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < cleanNumber.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted.write(' ');
      }
      formatted.write(cleanNumber[i]);
    }
    return formatted.toString();
  }

  String _getCardBrand(String number) {
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanNumber.isEmpty) return '';

    if (cleanNumber.startsWith('4')) {
      return 'Visa';
    } else if (cleanNumber.startsWith('5') ||
        (cleanNumber.length >= 2 &&
            int.tryParse(cleanNumber.substring(0, 2)) != null &&
            int.parse(cleanNumber.substring(0, 2)) >= 22 &&
            int.parse(cleanNumber.substring(0, 2)) <= 27)) {
      return 'Mastercard';
    } else if (cleanNumber.startsWith('3')) {
      return 'Amex';
    }

    return '';
  }

  Widget _buildCardBrandIcon() {
    switch (_cardBrand.toLowerCase()) {
      case 'visa':
        return Container(
          width: 40,
          height: 25,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'VISA',
              style: TextStyle(
                color: Color(0xFF1A1F71),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'mastercard':
        return Container(
          width: 40,
          height: 25,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEB9F00),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      case 'amex':
        return Container(
          width: 40,
          height: 25,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'AMEX',
              style: TextStyle(
                color: Color(0xFF006FCF),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      default:
        return Container(
          width: 40,
          height: 25,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.credit_card, color: Colors.white, size: 16),
        );
    }
  }

  Future<void> _processPayment() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_controller.details.complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all card details'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _stripeService.makePayment(
        amount: widget.amount.toString(),
        currency: 'usd',
        cardDetails: _controller.details,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors1.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isSmallScreen),

            // Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20 : 30,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 10),

                  // Section title
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your payment information is secure and encrypted',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Card Visual Preview
                  _buildCardPreview(),

                  const SizedBox(height: 30),

                  // Card Form Container
                  _buildCardFormContainer(),

                  const SizedBox(height: 20),

                  // Test cards info
                  _buildTestCardsInfo(),

                  const SizedBox(height: 40),

                  // Pay Button
                  _buildPayButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 30,
        vertical: 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Add \$${widget.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: isSmallScreen ? 28 : 36,
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
                  color: AppColors1.borderGreen.withOpacity(0.3),
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
    );
  }

  Widget _buildCardPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors1.deliveryCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card chip
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey[300]!, Colors.grey[400]!],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey[400]!, Colors.grey[500]!],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Card number
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _cardNumber.isEmpty ? '•••• •••• •••• ••••' : _cardNumber,
                    key: ValueKey(_cardNumber),
                    style: const TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const Spacer(),

                // Bottom row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Expiry
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VALID THRU',
                          style: TextStyle(
                            color: AppColors1.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _expiryMonth.isEmpty || _expiryYear.isEmpty
                                ? 'MM/YY'
                                : '$_expiryMonth/$_expiryYear',
                            key: ValueKey('$_expiryMonth/$_expiryYear'),
                            style: const TextStyle(
                              color: AppColors1.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Card brand
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        key: ValueKey(_cardBrand),
                        child: _buildCardBrandIcon(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFormContainer() {
    return Container(
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
            'Card Details',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                labelStyle: TextStyle(color: AppColors1.primaryGreen),
                hintStyle: TextStyle(
                  color: AppColors1.textTertiary.withOpacity(0.5),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors1.borderGreen.withOpacity(0.3),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors1.primaryGreen),
                ),
              ),
            ),
            child: CardFormField(
              controller: _controller,
              style: CardFormStyle(
                textColor: AppColors1.textPrimary,
                placeholderColor: AppColors1.textTertiary.withOpacity(0.5),
                backgroundColor: Colors.transparent,
                borderRadius: 0,
                borderWidth: 0,
                borderColor: Colors.transparent,
                fontSize: 16,
              ),
              enablePostalCode: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCardsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors1.primaryGreen.withOpacity(0.1),
            AppColors1.primaryGreen.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors1.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Test Cards',
                style: TextStyle(
                  color: AppColors1.primaryGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTestCardInfo('4242 4242 4242 4242', 'Success'),
          const SizedBox(height: 4),
          _buildTestCardInfo('4000 0025 0000 3155', 'Requires Auth'),
          const SizedBox(height: 4),
          _buildTestCardInfo('4000 0000 0000 9995', 'Declined'),
          const SizedBox(height: 8),
          Text(
            'Use any future date for expiry and any 3 digits for CVC',
            style: TextStyle(color: AppColors1.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return Container(
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
          onTap: _isLoading ? null : _processPayment,
          child: Center(
            child:
                _isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors1.backgroundColor,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      'Pay \$${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors1.backgroundColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestCardInfo(String cardNumber, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          cardNumber,
          style: TextStyle(
            color: AppColors1.textSecondary,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color:
                status == 'Success'
                    ? AppColors1.primaryGreen.withOpacity(0.2)
                    : status == 'Declined'
                    ? Colors.red.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color:
                  status == 'Success'
                      ? AppColors1.primaryGreen
                      : status == 'Declined'
                      ? Colors.red
                      : Colors.orange,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
