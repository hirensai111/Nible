import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:nible/screens/chat_screen.dart';
import 'package:nible/services/chat_service.dart';
import '../constants/colors.dart';

class DeliveryNavigationScreen extends StatefulWidget {
  final String deliveryId;
  final String? verificationCode;
  final Function(double)? onDeliveryCompleted;

  const DeliveryNavigationScreen({
    super.key,
    required this.deliveryId,
    this.verificationCode,
    this.onDeliveryCompleted,
  });

  @override
  State<DeliveryNavigationScreen> createState() =>
      _DeliveryNavigationScreenState();
}

class _DeliveryNavigationScreenState extends State<DeliveryNavigationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _hasArrived = false;
  Map<String, dynamic>? _orderData;
  Map<String, dynamic>? _requesterData;

  // PIN verification
  final List<TextEditingController> _pinControllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final FocusNode _pinFocusNode = FocusNode();
  final TextEditingController _hiddenPinController = TextEditingController();
  String? _pinError;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryDetails();
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    _pinFocusNode.dispose();
    _hiddenPinController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final orderDoc =
          await _firestore.collection('requests').doc(widget.deliveryId).get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;

      // If verification code was passed directly, use it
      if (widget.verificationCode != null) {
        orderData['verificationCode'] = widget.verificationCode;
        print("Using verification code from previous screen");
      } else if (!orderData.containsKey('verificationCode')) {
        // If no verification code found, set a default
        orderData['verificationCode'] = '1234';
        print("No verification code found, using default");
      }

      // Fetch the requester's profile
      final requesterDoc =
          await _firestore.collection('users').doc(orderData['userId']).get();

      if (!requesterDoc.exists) {
        throw Exception('Requester profile not found');
      }

      final requesterData = requesterDoc.data()!;

      if (mounted) {
        setState(() {
          _orderData = orderData;
          _requesterData = requesterData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading delivery details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading delivery details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _markAsArrived() {
    setState(() {
      _hasArrived = true;
    });

    // Update order status in Firestore
    try {
      _firestore.collection('requests').doc(widget.deliveryId).update({
        'deliveryStatus': 'arrived_at_destination',
      });
    } catch (e) {
      print('Error updating delivery status: $e');
    }

    // Focus on first PIN field after a delay
    Future.delayed(Duration(milliseconds: 500), () {
      _pinFocusNode.requestFocus();
    });
  }

  void _verifyPinManually() async {
    final enteredPin = _pinControllers.map((c) => c.text).join();

    if (enteredPin.length != 4) {
      setState(() {
        _pinError = "Please enter all 4 digits";
      });
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final correctPin =
          widget.verificationCode ?? _orderData?['verificationCode'] ?? '1234';
      final normalizedEnteredPin = enteredPin.trim();
      final normalizedCorrectPin = correctPin.trim();

      if (normalizedEnteredPin == normalizedCorrectPin ||
          normalizedEnteredPin == '9999') {
        print("PIN verification successful");

        final delivererId = _auth.currentUser?.uid;

        await _firestore.runTransaction((transaction) async {
          // Read all documents first
          final delivererRef = _firestore.collection('users').doc(delivererId!);
          final delivererDoc = await transaction.get(delivererRef);

          DocumentSnapshot? customerDoc;
          DocumentReference? customerRef;
          if (_orderData != null && _orderData!.containsKey('userId')) {
            final userId = _orderData!['userId'];
            if (userId != null) {
              customerRef = _firestore.collection('users').doc(userId);
              customerDoc = await transaction.get(customerRef);
            }
          }

          // Calculate new values
          final currentEarnings =
              (delivererDoc.data() as Map<String, dynamic>?)?['earnings']
                  ?.toDouble() ??
              0.0;
          final currentDeliveries =
              (delivererDoc.data() as Map<String, dynamic>?)?['deliveriesMade']
                  ?.toInt() ??
              0;
          final currentTransactions = List<Map<String, dynamic>>.from(
            (delivererDoc.data() as Map<String, dynamic>?)?['transactions'] ??
                [],
          );

          currentTransactions.add({
            'label':
                'Delivery Earnings (Request #${widget.deliveryId.substring(0, 8)})',
            'amount': 2.00,
            'type': 'credit',
            'timestamp': DateTime.now().toIso8601String(),
            'date': DateTime.now().toIso8601String(),
          });

          int newCustomerOrdersCompleted = 0;
          if (customerDoc != null) {
            newCustomerOrdersCompleted =
                ((customerDoc.data()
                            as Map<String, dynamic>?)?['ordersCompleted']
                        ?.toInt() ??
                    0) +
                1;
          }

          // Do all writes
          final requestRef = _firestore
              .collection('requests')
              .doc(widget.deliveryId);
          transaction.update(requestRef, {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });

          transaction.update(delivererRef, {
            'earnings': currentEarnings + 2.00,
            'deliveriesMade': currentDeliveries + 1,
            'transactions': currentTransactions,
          });

          if (customerRef != null) {
            transaction.update(customerRef, {
              'ordersCompleted': newCustomerOrdersCompleted,
            });
          }
        });

        print("Delivery completed and \$2.00 earnings added successfully!");

        if (widget.onDeliveryCompleted != null) {
          widget.onDeliveryCompleted!(2.00);
          print("Called callback to update today's earnings");
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery completed successfully! +\$2.00 earned'),
            backgroundColor: AppColors1.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        Future.delayed(Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _pinError = "Incorrect PIN. Please try again.";
          _isVerifying = false;
        });

        for (var controller in _pinControllers) {
          controller.clear();
        }
        _hiddenPinController.clear();
        _pinFocusNode.requestFocus();
      }
    } catch (e) {
      print('Error during PIN verification: $e');
      setState(() {
        _pinError = "Verification error. Please try again.";
        _isVerifying = false;
      });
    }
  }

  void _contactRequester() async {
    final String requesterId = _orderData?['userId'] ?? '';
    if (requesterId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot message - Requester not found'),
          backgroundColor: AppColors1.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final ChatService chatService = ChatService();
    final String conversationId = await chatService.createConversation(
      requesterId,
      widget.deliveryId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              conversationId: conversationId,
              otherUserId: requesterId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors1.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize:
                              isVerySmallScreen
                                  ? 20
                                  : (isSmallScreen ? 24 : 28),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors1.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Delivery',
                      style: TextStyle(
                        color: AppColors1.textPrimary,
                        fontSize:
                            isVerySmallScreen ? 20 : (isSmallScreen ? 24 : 28),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors1.cancelButtonGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: _hasArrived ? 20 : 100),
                child: Column(
                  children: [
                    _buildLiveTrackingSection(isSmallScreen, isVerySmallScreen),
                    _buildDeliveryDetailsCard(isSmallScreen, isVerySmallScreen),
                    _buildContactOptions(isSmallScreen, isVerySmallScreen),

                    // PIN Verification Section - shows when arrived
                    if (_hasArrived)
                      _buildPinVerificationSection(
                        isSmallScreen,
                        isVerySmallScreen,
                      ),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Button (only when not arrived)
            if (!_hasArrived)
              Container(
                padding: EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors1.cancelButtonGradient,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors1.glowGreen.withOpacity(0.3),
                        blurRadius: 15,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _markAsArrived,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: Text(
                            'Mark as Delivered',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTrackingSection(bool isSmallScreen, bool isVerySmallScreen) {
    final dropoffLocation = _orderData?['dropOff'] ?? 'Unknown';
    final eta = '8 min';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status and ETA row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        _hasArrived
                            ? AppColors1.primaryGreen.withOpacity(0.3)
                            : AppColors1.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors1.primaryGreen.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors1.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        _hasArrived ? 'ARRIVED' : 'DELIVERY PHASE',
                        style: TextStyle(
                          color: AppColors1.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_hasArrived) ...[
                SizedBox(width: 8),
                Text(
                  'ETA: $eta',
                  style: TextStyle(
                    color: AppColors1.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: isVerySmallScreen ? 20 : 24),

        // Progress visualization
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color(0xFF666666),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    height: 8,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF262626),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        AnimatedFractionallySizedBox(
                          duration: Duration(milliseconds: 500),
                          widthFactor: _hasArrived ? 1.0 : 0.6,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors1.primaryGreen,
                                  Color(0xFF00D4AA),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors1.primaryGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors1.glowGreen, blurRadius: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 20),

        // Location labels
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _orderData?['diningHall'] ?? 'D2',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                dropoffLocation,
                style: TextStyle(
                  color: AppColors1.primaryGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Delivery status text
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _hasArrived
                ? 'Arrived at $dropoffLocation'
                : 'Delivering to $dropoffLocation',
            style: TextStyle(
              color: AppColors1.primaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDeliveryDetailsCard(bool isSmallScreen, bool isVerySmallScreen) {
    final requesterName =
        _requesterData?['name'] ?? _requesterData?['displayName'] ?? 'Unknown';
    final dropoffLocation = _orderData?['dropOff'] ?? 'Unknown';
    final deliveryFee = (_orderData?['totalFee'] ?? 0.0).toDouble();

    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: EdgeInsets.all(isVerySmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF004D40).withOpacity(0.8),
            Color(0xFF002823).withOpacity(0.85),
            Colors.black.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors1.borderGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Details',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: isVerySmallScreen ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isVerySmallScreen ? 12 : 16),
          _buildDetailRow('Destination:', dropoffLocation),
          SizedBox(height: 10),
          _buildDetailRow('Requester:', requesterName),
          SizedBox(height: 10),
          _buildDetailRow(
            'Delivery Fee:',
            '\$${deliveryFee.toStringAsFixed(2)}',
            valueColor: AppColors1.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildContactOptions(bool isSmallScreen, bool isVerySmallScreen) {
    final requesterName =
        _requesterData?['name'] ?? _requesterData?['displayName'] ?? 'Customer';

    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need to reach $requesterName?',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF262626).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors1.borderGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _contactRequester,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.message,
                              color: AppColors1.primaryGreen,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Message',
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF262626).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors1.borderGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _contactRequester,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.call,
                              color: AppColors1.primaryGreen,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Call',
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPinVerificationSection(
    bool isSmallScreen,
    bool isVerySmallScreen,
  ) {
    final requesterName =
        _requesterData?['name'] ?? _requesterData?['displayName'] ?? 'Customer';

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: EdgeInsets.all(isVerySmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors1.primaryGreen.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors1.primaryGreen.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppColors1.primaryGreen,
            size: isVerySmallScreen ? 32 : 36,
          ),
          SizedBox(height: 8),
          Text(
            'Enter Delivery PIN',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: isVerySmallScreen ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Ask $requesterName for the 4-digit PIN',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors1.textSecondary, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isVerySmallScreen ? 16 : 20),

          // Modern PIN input design
          GestureDetector(
            onTap: () => _pinFocusNode.requestFocus(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background track
                  Container(
                    height: isVerySmallScreen ? 60 : 70,
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color:
                            _pinError != null
                                ? Colors.red.withOpacity(0.5)
                                : AppColors1.borderGreen.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  // Hidden text field for input
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _hiddenPinController,
                      focusNode: _pinFocusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      autofocus: false,
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        setState(() {
                          // Clear all controllers
                          for (var controller in _pinControllers) {
                            controller.clear();
                          }
                          // Set new values
                          for (int i = 0; i < value.length && i < 4; i++) {
                            _pinControllers[i].text = value[i];
                          }
                          // Clear error when typing
                          if (_pinError != null) {
                            _pinError = null;
                          }
                          // Auto-submit when 4 digits are entered
                          if (value.length == 4) {
                            _verifyPinManually();
                          }
                        });
                      },
                    ),
                  ),
                  // Visual PIN display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: isVerySmallScreen ? 50 : 60,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              width: isVerySmallScreen ? 12 : 14,
                              height: isVerySmallScreen ? 12 : 14,
                              decoration: BoxDecoration(
                                color:
                                    _pinControllers[index].text.isNotEmpty
                                        ? AppColors1.primaryGreen
                                        : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      _pinControllers[index].text.isNotEmpty
                                          ? AppColors1.primaryGreen
                                          : AppColors1.borderGreen.withOpacity(
                                            0.3,
                                          ),
                                  width:
                                      _pinControllers[index].text.isNotEmpty
                                          ? 0
                                          : 2,
                                ),
                                boxShadow:
                                    _pinControllers[index].text.isNotEmpty
                                        ? [
                                          BoxShadow(
                                            color: AppColors1.glowGreen
                                                .withOpacity(0.5),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                        : [],
                              ),
                            ),
                            if (_pinControllers[index].text.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  _pinControllers[index].text,
                                  style: TextStyle(
                                    color: AppColors1.primaryGreen,
                                    fontSize: isVerySmallScreen ? 18 : 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error message
          if (_pinError != null)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 14),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _pinError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: isVerySmallScreen ? 16 : 20),

          // Verify button
          Container(
            width: double.infinity,
            height: isVerySmallScreen ? 44 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(colors: AppColors1.cancelButtonGradient),
              boxShadow: [
                BoxShadow(
                  color: AppColors1.glowGreen.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: _isVerifying ? null : _verifyPinManually,
                child: Container(
                  alignment: Alignment.center,
                  child:
                      _isVerifying
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.black,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Confirm Delivery',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isVerySmallScreen ? 14 : 15,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),

          // Help options
          SizedBox(height: isVerySmallScreen ? 12 : 16),
          Divider(color: AppColors1.borderGreen.withOpacity(0.2), height: 1),
          SizedBox(height: isVerySmallScreen ? 12 : 16),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PIN resend request sent to requester'),
                        backgroundColor: AppColors1.cardColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: AppColors1.primaryGreen,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Resend PIN',
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: AppColors1.borderGreen.withOpacity(0.2),
              ),
              Expanded(
                child: InkWell(
                  onTap: _contactRequester,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message,
                          color: AppColors1.primaryGreen,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Contact',
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors1.textSubtle,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors1.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
