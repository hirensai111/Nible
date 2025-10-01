import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nible/screens/order_tracking_screen.dart';
import '../constants/colors.dart';

class RequestConfirmationScreen extends StatefulWidget {
  final String requestId;
  final String diningHall;
  final String deliveryLocation;
  final double totalFee;
  final String orderReference;

  const RequestConfirmationScreen({
    Key? key,
    required this.requestId,
    required this.diningHall,
    required this.deliveryLocation,
    required this.totalFee,
    required this.orderReference,
  }) : super(key: key);

  @override
  State<RequestConfirmationScreen> createState() =>
      _RequestConfirmationScreenState();
}

class _RequestConfirmationScreenState extends State<RequestConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkmarkAnimationController;
  late Animation<double> _checkmarkAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  String _currentStatus = 'pending';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<DocumentSnapshot>? _requestStream;

  @override
  void initState() {
    super.initState();

    _checkmarkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _checkmarkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkAnimationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkAnimationController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkmarkAnimationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _checkmarkAnimationController.forward();
      HapticFeedback.mediumImpact();
    });

    _setupRequestListener();
  }

  void _setupRequestListener() {
    _requestStream =
        _firestore.collection('requests').doc(widget.requestId).snapshots();

    _requestStream?.listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] != null && mounted) {
          setState(() {
            _currentStatus = data['status'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _checkmarkAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 410;

    // Responsive sizing
    final horizontalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final titleFontSize = isSmallScreen ? 28.0 : (isMediumScreen ? 32.0 : 36.0);
    final checkmarkSize =
        isSmallScreen ? 100.0 : (isMediumScreen ? 110.0 : 120.0);
    final buttonHeight = isSmallScreen ? 48.0 : (isMediumScreen ? 52.0 : 55.0);

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Request Confirmed',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: isSmallScreen ? 32 : 36,
                      height: isSmallScreen ? 32 : 36,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors1.textPrimary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.check,
                        color: AppColors1.primaryGreen,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 40 : 60),

                // Animated checkmark circle - NO BACKDROP FILTER
                Center(
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: checkmarkSize,
                          height: checkmarkSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors1.primaryGreen.withOpacity(0.15),
                            border: Border.all(
                              color: AppColors1.primaryGreen,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors1.glowGreen,
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _checkmarkAnimation,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: Size(
                                    checkmarkSize * 0.5,
                                    checkmarkSize * 0.5,
                                  ),
                                  painter: CheckmarkPainter(
                                    progress: _checkmarkAnimation.value,
                                    color: AppColors1.primaryGreen,
                                    strokeWidth: 4,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: isSmallScreen ? 30 : 40),

                // Success text
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Request Successful!',
                              style: TextStyle(
                                color: AppColors1.primaryGreen,
                                fontSize: isSmallScreen ? 24 : 28,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your pickup request has been received',
                              style: TextStyle(
                                color: AppColors1.textSecondary,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: isSmallScreen ? 30 : 40),

                // Order Details section - NO BACKDROP FILTER
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors1.primaryGreen.withOpacity(0.2),
                        AppColors1.primaryGreen.withOpacity(0.1),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors1.borderGreen, width: 1),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Details',
                          style: TextStyle(
                            color: AppColors1.textPrimary,
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        _buildDetailRow(
                          'Pickup Location',
                          widget.diningHall,
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Delivery To',
                          widget.deliveryLocation,
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Order Reference',
                          widget.orderReference,
                          isSmallScreen: isSmallScreen,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          'Total Fee',
                          '\$${widget.totalFee.toStringAsFixed(2)}',
                          valueColor: AppColors1.primaryGreen,
                          valueFontWeight: FontWeight.w600,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Current Status section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
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
                      Text(
                        'Current Status',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: isSmallScreen ? 14 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors1.backgroundColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: AppColors1.borderGreen.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(_currentStatus),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusColor(
                                      _currentStatus,
                                    ).withOpacity(0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              child: Text(
                                _getStatusText(_currentStatus),
                                style: TextStyle(
                                  color: AppColors1.textPrimary,
                                  fontSize: isSmallScreen ? 13 : 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 30 : 40),

                // Track Order button (outlined)
                Container(
                  width: double.infinity,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    border: Border.all(
                      color: AppColors1.primaryGreen,
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(27),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => OrderTrackingScreen(
                                  order: {
                                    'id': widget.requestId,
                                    'diningHall': widget.diningHall,
                                    'dropOff': widget.deliveryLocation,
                                    'totalFee': widget.totalFee,
                                    'orderReference': widget.orderReference,
                                    'status': _currentStatus,
                                  },
                                ),
                          ),
                        );
                      },
                      child: Center(
                        child: Text(
                          'Track Order',
                          style: TextStyle(
                            color: AppColors1.primaryGreen,
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Return to Home button (filled)
                Container(
                  width: double.infinity,
                  height: buttonHeight,
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
                      onTap: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      child: Center(
                        child: Text(
                          'Return to Home',
                          style: TextStyle(
                            color: AppColors1.backgroundColor,
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors1.primaryGreen;
      case 'completed':
        return AppColors1.primaryblue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'Delivery person assigned';
      case 'completed':
        return 'Delivery completed';
      case 'cancelled':
        return 'Delivery cancelled';
      case 'pending':
      default:
        return 'Looking for a deliverer...';
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color valueColor = AppColors1.textPrimary,
    FontWeight valueFontWeight = FontWeight.normal,
    required bool isSmallScreen,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors1.textSecondary,
              fontSize: isSmallScreen ? 13 : 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: valueFontWeight,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    final path = Path();

    final startPoint = Offset(size.width * 0.2, size.height * 0.5);
    final middlePoint = Offset(size.width * 0.4, size.height * 0.7);
    final endPoint = Offset(size.width * 0.8, size.height * 0.3);

    if (progress < 0.5) {
      final adjustedProgress = progress * 2;
      final currentEndX =
          startPoint.dx + (middlePoint.dx - startPoint.dx) * adjustedProgress;
      final currentEndY =
          startPoint.dy + (middlePoint.dy - startPoint.dy) * adjustedProgress;
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(currentEndX, currentEndY);
    } else {
      path.moveTo(startPoint.dx, startPoint.dy);
      path.lineTo(middlePoint.dx, middlePoint.dy);
      final adjustedProgress = (progress - 0.5) * 2;
      final currentEndX =
          middlePoint.dx + (endPoint.dx - middlePoint.dx) * adjustedProgress;
      final currentEndY =
          middlePoint.dy + (endPoint.dy - middlePoint.dy) * adjustedProgress;
      path.lineTo(currentEndX, currentEndY);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
