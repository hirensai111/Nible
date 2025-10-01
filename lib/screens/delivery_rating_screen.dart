import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';

class DeliveryRatingScreen extends StatefulWidget {
  final String orderId;
  final String delivererId;
  final String delivererName;
  final String pickupLocation;
  final String dropoffLocation;

  const DeliveryRatingScreen({
    Key? key,
    required this.orderId,
    required this.delivererId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.delivererName,
  }) : super(key: key);

  @override
  State<DeliveryRatingScreen> createState() => _DeliveryRatingScreenState();
}

class _DeliveryRatingScreenState extends State<DeliveryRatingScreen> {
  int _delivererRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  final Set<String> _selectedTags = {};

  final List<String> _quickTags = [
    'On Time',
    'Very Polite',
    'Fast',
    'Friendly',
    'Careful with Order',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_delivererRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please rate your deliverer before submitting'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final DateTime now = DateTime.now();

      // 1. First update the request document with rating information
      await _firestore.collection('requests').doc(widget.orderId).update({
        'rating': _delivererRating,
        'feedback': _feedbackController.text,
        'tags': _selectedTags.toList(),
        'ratingTimestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the deliverer's statistics
      if (widget.delivererId.isNotEmpty) {
        DocumentReference delivererRef = _firestore
            .collection('users')
            .doc(widget.delivererId);

        DocumentSnapshot delivererDoc = await delivererRef.get();

        if (delivererDoc.exists) {
          Map<String, dynamic> delivererData =
              delivererDoc.data() as Map<String, dynamic>? ?? {};

          int totalRatings = 0;
          double avgRating = 0.0;
          List<dynamic> ratings = [];

          if (delivererData.containsKey('totalRatings')) {
            totalRatings = delivererData['totalRatings'] as int? ?? 0;
          }

          if (delivererData.containsKey('averageRating')) {
            avgRating =
                (delivererData['averageRating'] as num?)?.toDouble() ?? 0.0;
          }

          if (delivererData.containsKey('ratings') &&
              delivererData['ratings'] is List) {
            ratings = delivererData['ratings'] as List<dynamic>;
          }

          double newAvgRating =
              totalRatings > 0
                  ? ((avgRating * totalRatings) + _delivererRating) /
                      (totalRatings + 1)
                  : _delivererRating.toDouble();

          Map<String, dynamic> ratingRecord = {
            'orderId': widget.orderId,
            'rating': _delivererRating,
            'feedback': _feedbackController.text,
            'tags': _selectedTags.toList(),
            'timestamp': now.toIso8601String(),
          };

          ratings.add(ratingRecord);

          await delivererRef.update({
            'averageRating': newAvgRating,
            'totalRatings': totalRatings + 1,
            'ratings': ratings,
            'deliveriesMade': ratings.length,
          });
        } else {
          List<Map<String, dynamic>> initialRatings = [
            {
              'orderId': widget.orderId,
              'rating': _delivererRating,
              'feedback': _feedbackController.text,
              'tags': _selectedTags.toList(),
              'timestamp': now.toIso8601String(),
            },
          ];

          await delivererRef.set({
            'averageRating': _delivererRating.toDouble(),
            'totalRatings': 1,
            'ratings': initialRatings,
            'deliveriesMade': 1,
          }, SetOptions(merge: true));
        }
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thank you for your feedback!'),
            backgroundColor: AppColors1.primaryGreen,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Rating submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: ${e.toString()}'),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
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
    final starSize = isSmallScreen ? 26.0 : (isMediumScreen ? 30.0 : 34.0);
    final buttonHeight = isSmallScreen ? 48.0 : (isMediumScreen ? 52.0 : 55.0);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
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
                  _buildHeader(isSmallScreen, titleFontSize),
                  SizedBox(height: isSmallScreen ? 24 : 30),
                  _buildOrderDetails(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 30 : 40),
                  _buildDelivererRating(isSmallScreen, starSize),
                  SizedBox(height: isSmallScreen ? 30 : 40),
                  _buildFeedbackInput(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 30 : 40),
                  _buildQuickTags(isSmallScreen),
                  SizedBox(height: isSmallScreen ? 40 : 50),
                  _buildSubmitButton(isSmallScreen, buttonHeight),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen, double titleFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Rate Your Experience',
                style: TextStyle(
                  color: AppColors1.textPrimary,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: isSmallScreen ? 32 : 36,
              height: isSmallScreen ? 32 : 36,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors1.textPrimary, width: 2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.star,
                color: AppColors1.primaryGreen,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'How was your delivery?',
          style: TextStyle(
            color: AppColors1.textSecondary,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails(bool isSmallScreen) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors1.deliveryCardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
        child: Column(
          children: [
            Container(
              width: isSmallScreen ? 50 : 60,
              height: isSmallScreen ? 50 : 60,
              decoration: BoxDecoration(
                color: AppColors1.backgroundColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors1.borderGreen.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors1.primaryGreen,
                size: isSmallScreen ? 28 : 32,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Text(
              'Order Delivered!',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.pickupLocation} → ${widget.dropoffLocation}',
              style: TextStyle(
                color: AppColors1.textSecondary,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delivery_dining,
                  color: AppColors1.primaryGreen,
                  size: isSmallScreen ? 18 : 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.delivererName,
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelivererRating(bool isSmallScreen, double starSize) {
    String delivererInitials =
        widget.delivererName
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0] : '')
            .join()
            .toUpperCase();

    return Container(
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
            'Rate Your Deliverer',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Row(
            children: [
              Container(
                width: isSmallScreen ? 42 : 48,
                height: isSmallScreen ? 42 : 48,
                decoration: BoxDecoration(
                  color: AppColors1.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors1.borderGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    delivererInitials,
                    style: TextStyle(
                      color: AppColors1.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 16 : 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _delivererRating = index + 1;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 2 : 4,
                          ),
                          child: Icon(
                            index < _delivererRating
                                ? Icons.star
                                : Icons.star_border,
                            color:
                                index < _delivererRating
                                    ? AppColors1.primaryGreen
                                    : AppColors1.textTertiary,
                            size: starSize,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackInput(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Feedback',
          style: TextStyle(
            color: AppColors1.textPrimary,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Optional',
          style: TextStyle(
            color: AppColors1.textSecondary,
            fontSize: isSmallScreen ? 12 : 14,
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
          child: TextField(
            controller: _feedbackController,
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: isSmallScreen ? 14 : 16,
            ),
            maxLines: isSmallScreen ? 3 : 4,
            decoration: InputDecoration(
              hintText: 'Share your experience or suggestions...',
              hintStyle: TextStyle(
                color: AppColors1.textTertiary.withOpacity(0.5),
                fontSize: isSmallScreen ? 14 : 16,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTags(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tags',
          style: TextStyle(
            color: AppColors1.textPrimary,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        Wrap(
          spacing: isSmallScreen ? 6 : 8,
          runSpacing: isSmallScreen ? 6 : 8,
          children:
              _quickTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => _toggleTag(tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors1.primaryGreen
                              : AppColors1.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected
                                ? AppColors1.primaryGreen
                                : AppColors1.borderGreen.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: AppColors1.glowGreen,
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color:
                            isSelected
                                ? AppColors1.backgroundColor
                                : AppColors1.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isSmallScreen, double buttonHeight) {
    return Container(
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
          onTap: _isSubmitting ? null : _submitRating,
          child: Center(
            child:
                _isSubmitting
                    ? SizedBox(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      child: const CircularProgressIndicator(
                        color: AppColors1.backgroundColor,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      'Submit Feedback',
                      style: TextStyle(
                        color: AppColors1.backgroundColor,
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
