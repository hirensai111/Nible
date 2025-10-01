import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:nible/screens/chat_screen.dart';
import 'package:nible/services/chat_service.dart';
import 'dart:math'; // For generating random code
import 'dart:async'; // Added for StreamSubscription
import '../constants/colors.dart';
import 'delivery_rating_screen.dart'; // Import your rating screen

class OrderTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderTrackingScreen({Key? key, required this.order}) : super(key: key);

  @override
  _OrderTrackingScreenState createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _contentVisible = false;
  Map<String, dynamic>? _delivererData;
  String? _verificationCode;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Start animations after a brief delay to ensure smooth transition
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
        setState(() {
          _contentVisible = true;
        });
      }
    });

    _loadDelivererInfo();
    _generateVerificationCode();
    _listenForOrderUpdates();
  }

  void _listenForOrderUpdates() {
    final orderId = widget.order['id'];
    if (orderId == null) return;

    _orderSubscription = _firestore
        .collection('requests')
        .doc(orderId)
        .snapshots()
        .listen(
          (snapshot) {
            // Check if widget is still mounted before processing
            if (!mounted) return;

            if (!snapshot.exists) return;

            final updatedOrder = snapshot.data() as Map<String, dynamic>;
            final newStatus = updatedOrder['status'];

            // Double-check mounted state before setState
            if (mounted && newStatus != widget.order['status']) {
              setState(() {
                widget.order['status'] = newStatus;

                if (newStatus == 'completed' &&
                    updatedOrder['completedAt'] != null) {
                  widget.order['completedAt'] = updatedOrder['completedAt'];
                }
              });

              // Check mounted state before navigation
              if (mounted &&
                  (newStatus == 'completed' || newStatus == 'delivered')) {
                _orderSubscription?.cancel();

                final delivererId = updatedOrder['deliveryPersonId'];
                final delivererName =
                    _delivererData?['name'] ?? 'Your Deliverer';

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder:
                        (context) => DeliveryRatingScreen(
                          orderId: orderId,
                          delivererId: delivererId,
                          delivererName: delivererName,
                          pickupLocation: widget.order['diningHall'] ?? '',
                          dropoffLocation: widget.order['dropOff'] ?? '',
                        ),
                  ),
                );
              }
            }
          },
          onError: (error) {
            // Handle any potential errors in the stream
            print('Error listening to order updates: $error');
          },
        );
  }

  void _generateVerificationCode() {
    if (widget.order['status'] == 'picked_up' &&
        widget.order['verificationCode'] == null) {
      final random = Random();
      final code = (1000 + random.nextInt(9000)).toString();

      // Check if widget is still mounted before setState
      if (mounted) {
        setState(() {
          _verificationCode = code;
        });
      }

      try {
        _firestore.collection('requests').doc(widget.order['id']).update({
          'verificationCode': code,
        });
      } catch (e) {
        print('Error saving verification code: $e');
      }
    } else if (widget.order['verificationCode'] != null) {
      // Check if widget is still mounted before setState
      if (mounted) {
        setState(() {
          _verificationCode = widget.order['verificationCode'];
        });
      }
    }
  }

  Future<void> _loadDelivererInfo() async {
    if (widget.order['deliveryPersonId'] == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final delivererDoc =
          await _firestore
              .collection('users')
              .doc(widget.order['deliveryPersonId'])
              .get();

      // Check if widget is still mounted before setState
      if (mounted) {
        if (delivererDoc.exists) {
          setState(() {
            _delivererData = delivererDoc.data();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading deliverer info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'accepted':
        return 1;
      case 'picked_up':
        return 2;
      case 'completed':
        return 3;
      default:
        return 0;
    }
  }

  // Responsive helper methods
  double getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 12.0;
    if (width < 400) return 16.0;
    return 20.0;
  }

  double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.85;
    if (width < 400) return baseSize * 0.9;
    return baseSize;
  }

  double getResponsiveHeaderSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 22.0;
    if (width < 400) return 25.0;
    return 28.0;
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String from = widget.order['diningHall'] ?? 'Unknown';
    final String to = widget.order['dropOff'] ?? 'My Room';
    final String status = widget.order['status'] ?? 'pending';

    final Map<String, String> statusTimes = {};

    if (widget.order['timestamp'] != null &&
        widget.order['timestamp'] is Timestamp) {
      statusTimes['Order Confirmed'] = DateFormat(
        'h:mm a',
      ).format(widget.order['timestamp'].toDate());
    }

    if (widget.order['acceptedAt'] != null &&
        widget.order['acceptedAt'] is Timestamp) {
      statusTimes['Deliverer on the way to pickup'] = DateFormat(
        'h:mm a',
      ).format(widget.order['acceptedAt'].toDate());
    }

    if (widget.order['pickedUpAt'] != null &&
        widget.order['pickedUpAt'] is Timestamp) {
      statusTimes['Food picked up'] = DateFormat(
        'h:mm a',
      ).format(widget.order['pickedUpAt'].toDate());
    }

    if (widget.order['completedAt'] != null &&
        widget.order['completedAt'] is Timestamp) {
      statusTimes['Delivered'] = DateFormat(
        'h:mm a',
      ).format(widget.order['completedAt'].toDate());
    }

    final currentStep = _getStepIndex(status);
    final bool delivererAssigned =
        widget.order['deliveryPersonId'] != null && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      appBar: null,
      body: Container(
        decoration: const BoxDecoration(color: AppColors1.backgroundColor),
        child: SafeArea(
          child: Column(
            children: [
              // Custom header with animation - responsive
              FadeTransition(
                opacity: _fadeAnimation,
                child: _buildCustomHeader(),
              ),

              // Main content with smooth animations
              Expanded(
                child: AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child:
                            _contentVisible
                                ? _buildContent(
                                  from,
                                  to,
                                  currentStep,
                                  statusTimes,
                                  delivererAssigned,
                                  status,
                                )
                                : Container(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    String from,
    String to,
    int currentStep,
    Map<String, String> statusTimes,
    bool delivererAssigned,
    String status,
  ) {
    final padding = getResponsivePadding(context);

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        // Order info section with staggered animation
        _buildAnimatedCard(child: _buildOrderInfoCard(from, to), delay: 100),

        SizedBox(height: padding),

        // Deliverer info section (if assigned) - using delivery card gradient
        if (delivererAssigned && _delivererData != null)
          _buildAnimatedCard(child: _buildDelivererSection(), delay: 200),

        // Live tracking (if deliverer assigned)
        if (delivererAssigned)
          _buildAnimatedCard(
            child: _buildLiveTrackingSection(currentStep),
            delay: 300,
          ),

        // Order status timeline
        _buildAnimatedCard(
          child: _buildOrderStatusTimeline(currentStep, statusTimes),
          delay: 400,
        ),

        // Show verification code if food is picked up
        if (status == 'picked_up' && _verificationCode != null)
          _buildAnimatedCard(
            child: _buildVerificationCodeSection(),
            delay: 500,
          ),

        // Extra padding at bottom for small screens
        SizedBox(height: padding),
      ],
    );
  }

  Widget _buildAnimatedCard({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _buildCustomHeader() {
    final padding = getResponsivePadding(context);
    final headerSize = getResponsiveHeaderSize(context);

    return Container(
      padding: EdgeInsets.only(
        left: padding + 10,
        right: padding + 10,
        top: padding,
        bottom: padding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Track Order',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: headerSize,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors1.cancelButtonGradient,
              ),
              borderRadius: BorderRadius.circular(27),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getResponsiveFontSize(context, 16),
                    vertical: getResponsiveFontSize(context, 8),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: getResponsiveFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(String from, String to) {
    final padding = getResponsivePadding(context);

    return Container(
      padding: EdgeInsets.all(padding + 5),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        children: [
          _buildDetailRow('From:', from),
          SizedBox(height: padding * 0.75),
          _buildDetailRow('To:', to),
          SizedBox(height: padding * 0.75),
          _buildDetailRow('Estimated Time:', '15-20 min'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final fontSize = getResponsiveFontSize(context, 16);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors1.textSubtle,
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Flexible(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDelivererSection() {
    final String name = _delivererData?['name'] ?? 'Hiren Sai';
    final double rating = (_delivererData?['averageRating'] ?? 4.2).toDouble();
    final int deliveries = (_delivererData?['deliveriesMade'] ?? 6).toInt();
    final padding = getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final nameParts = name.split(' ');
    String initials =
        nameParts.length > 1
            ? '${nameParts[0][0]}${nameParts[1][0]}'
            : (name.isNotEmpty ? name[0] : 'U');

    return Container(
      padding: EdgeInsets.all(padding + 5),
      margin: EdgeInsets.only(bottom: padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors1.deliveryCardGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Plus',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: getResponsiveFontSize(context, 26),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Your Deliverer',
            style: TextStyle(
              color: AppColors1.textSecondary,
              fontSize: getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: padding),
          isSmallScreen
              ? Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors1.iconBackgroundColor.withOpacity(
                            0.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors1.borderGreen.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: AppColors1.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: getResponsiveFontSize(context, 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: getResponsiveFontSize(context, 18),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            _buildRatingRow(rating, deliveries),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (widget.order['status'] != 'completed' &&
                      widget.order['status'] != 'delivered')
                    Padding(
                      padding: EdgeInsets.only(top: padding),
                      child: SizedBox(
                        width: double.infinity,
                        child: _buildMessageButton(),
                      ),
                    ),
                ],
              )
              : Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors1.iconBackgroundColor.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors1.borderGreen.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: AppColors1.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: getResponsiveFontSize(context, 20),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: padding),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: getResponsiveFontSize(context, 18),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _buildRatingRow(rating, deliveries),
                      ],
                    ),
                  ),
                  if (widget.order['status'] != 'completed' &&
                      widget.order['status'] != 'delivered')
                    _buildMessageButton(),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(double rating, int deliveries) {
    return Row(
      children: [
        Icon(
          Icons.star,
          color: AppColors1.primaryGreen,
          size: getResponsiveFontSize(context, 16),
        ),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)}',
          style: TextStyle(
            color: AppColors1.textTertiary,
            fontSize: getResponsiveFontSize(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$deliveries deliveries',
              style: TextStyle(
                color: AppColors1.textTertiary,
                fontSize: getResponsiveFontSize(context, 12),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors1.cancelButtonGradient),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(27),
          onTap: () => _openChatWithDeliverer(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Message',
              style: TextStyle(
                color: Colors.black,
                fontSize: getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveTrackingSection(int currentStep) {
    // Get actual locations from order data
    final String pickupLocation = widget.order['diningHall'] ?? 'Pickup';
    final String dropoffLocation = widget.order['dropOff'] ?? 'Dropoff';
    final padding = getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(padding + 5),
      margin: EdgeInsets.only(bottom: padding),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Tracking',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: padding),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
            height: isSmallScreen ? 80 : 100,
            child: Row(
              children: [
                // Starting point (Pickup)
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isSmallScreen ? 10 : 12,
                        height: isSmallScreen ? 10 : 12,
                        decoration: BoxDecoration(
                          color:
                              currentStep >= 1
                                  ? AppColors1.primaryGreen
                                  : AppColors1.textSubtle,
                          shape: BoxShape.circle,
                          boxShadow:
                              currentStep >= 1
                                  ? [
                                    BoxShadow(
                                      color: AppColors1.glowGreen,
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pickupLocation,
                        style: TextStyle(
                          color:
                              currentStep >= 1
                                  ? AppColors1.primaryGreen
                                  : AppColors1.textSubtle,
                          fontSize: getResponsiveFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Progress line with gradient
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Base line
                      Container(
                        height: isSmallScreen ? 6 : 8,
                        decoration: BoxDecoration(
                          color: AppColors1.iconBackgroundColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // Progress line with gradient animation
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween(
                          begin: 0.0,
                          end: _getProgressValue(currentStep),
                        ),
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              height: isSmallScreen ? 6 : 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors1.primaryGreen,
                                    Color(0xFF00D4AA),
                                    Color(0xFF00A896),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Destination point (Dropoff)
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isSmallScreen ? 10 : 12,
                        height: isSmallScreen ? 10 : 12,
                        decoration: BoxDecoration(
                          color:
                              currentStep >= 3
                                  ? AppColors1.primaryGreen
                                  : AppColors1.textSubtle,
                          shape: BoxShape.circle,
                          boxShadow:
                              currentStep >= 3
                                  ? [
                                    BoxShadow(
                                      color: AppColors1.glowGreen,
                                      blurRadius: 12,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dropoffLocation,
                        style: TextStyle(
                          color:
                              currentStep >= 3
                                  ? AppColors1.primaryGreen
                                  : AppColors1.textSubtle,
                          fontSize: getResponsiveFontSize(context, 11),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Current status text
          SizedBox(height: padding * 0.75),
          Center(
            child: Text(
              _getCurrentStatusText(currentStep),
              style: TextStyle(
                color: AppColors1.primaryGreen,
                fontSize: getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get progress value based on order status
  double _getProgressValue(int currentStep) {
    switch (currentStep) {
      case 0:
        return 0.0; // pending
      case 1:
        return 0.3; // accepted (deliverer heading to pickup)
      case 2:
        return 0.7; // picked_up (heading to delivery)
      case 3:
        return 1.0; // completed
      default:
        return 0.0;
    }
  }

  // Helper method to get current status text
  String _getCurrentStatusText(int currentStep) {
    final String pickupLocation =
        widget.order['diningHall'] ?? 'pickup location';
    final String dropoffLocation =
        widget.order['dropOff'] ?? 'delivery location';

    switch (currentStep) {
      case 0:
        return 'Waiting for deliverer...';
      case 1:
        return 'Deliverer heading to $pickupLocation';
      case 2:
        return 'Food picked up, heading to $dropoffLocation';
      case 3:
        return 'Delivered!';
      default:
        return 'Order processing...';
    }
  }

  Widget _buildOrderStatusTimeline(
    int currentStep,
    Map<String, String> statusTimes,
  ) {
    final List<Map<String, dynamic>> statusSteps = [
      {
        'title': 'Order Confirmed',
        'step': 0,
        'time': statusTimes['Order Confirmed'],
      },
      {
        'title': 'Deliverer on the way to pickup',
        'step': 1,
        'time': statusTimes['Deliverer on the way to pickup'],
      },
      {
        'title': 'Food picked up',
        'step': 2,
        'time': statusTimes['Food picked up'],
      },
      {'title': 'Delivered', 'step': 3, 'time': statusTimes['Delivered']},
    ];

    final padding = getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(padding + 5),
      margin: EdgeInsets.only(bottom: padding),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: padding),
          ...statusSteps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final bool isCompleted = step['step'] <= currentStep;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 200 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: padding * 0.8),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: isSmallScreen ? 16 : 20,
                            height: isSmallScreen ? 16 : 20,
                            decoration: BoxDecoration(
                              color:
                                  isCompleted
                                      ? AppColors1.primaryGreen
                                      : AppColors1.iconBackgroundColor,
                              shape: BoxShape.circle,
                              boxShadow:
                                  isCompleted
                                      ? [
                                        BoxShadow(
                                          color: AppColors1.glowGreen,
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ]
                                      : null,
                            ),
                            child:
                                isCompleted
                                    ? Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: isSmallScreen ? 10 : 12,
                                    )
                                    : null,
                          ),
                          SizedBox(width: padding * 0.75),
                          Expanded(
                            child: Text(
                              step['title'],
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: getResponsiveFontSize(
                                  context,
                                  isSmallScreen ? 14 : 16,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          if (step['time'] != null)
                            Text(
                              step['time'],
                              style: TextStyle(
                                color: AppColors1.textSubtle,
                                fontSize: getResponsiveFontSize(context, 14),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildVerificationCodeSection() {
    final padding = getResponsivePadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(padding + 5),
      margin: EdgeInsets.only(bottom: padding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors1.deliveryCardGradient,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors1.primaryGreen.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors1.subtleGlow,
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isSmallScreen ? 35 : 40,
                height: isSmallScreen ? 35 : 40,
                decoration: BoxDecoration(
                  color: AppColors1.iconBackgroundColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors1.borderGreen.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.verified_user,
                  color: AppColors1.primaryGreen,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Delivery Verification',
                  style: TextStyle(
                    color: AppColors1.textPrimary,
                    fontSize: getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: padding * 0.75),
          Text(
            'Show this code to your deliverer when they arrive:',
            style: TextStyle(
              color: AppColors1.textSecondary,
              fontSize: getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: padding),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 15 : 20),
            decoration: BoxDecoration(
              color: AppColors1.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors1.primaryGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors1.glowGreen,
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _verificationCode ?? '----',
                style: TextStyle(
                  color: AppColors1.primaryGreen,
                  fontSize: getResponsiveFontSize(
                    context,
                    isSmallScreen ? 28 : 32,
                  ),
                  fontWeight: FontWeight.bold,
                  letterSpacing: isSmallScreen ? 6 : 8,
                ),
              ),
            ),
          ),
          SizedBox(height: padding * 0.75),
          Text(
            'The deliverer will need to enter this code to complete the delivery.',
            style: TextStyle(
              color: AppColors1.textTertiary,
              fontSize: getResponsiveFontSize(context, 12),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openChatWithDeliverer() async {
    final String delivererId = widget.order['deliveryPersonId'] ?? '';
    if (delivererId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot message - Deliverer not found'),
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
      delivererId,
      widget.order['id'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChatScreen(
              conversationId: conversationId,
              otherUserId: delivererId,
            ),
      ),
    );
  }
}
