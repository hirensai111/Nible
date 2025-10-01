import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:nible/screens/chat_screen.dart';
import 'package:nible/services/chat_service.dart';
import '../constants/colors.dart';
import '../models/delivery.dart';
import 'delivery_navigation_screen.dart';

class DeliveryPickupScreen extends StatefulWidget {
  final String deliveryId;
  final Function(double)? onDeliveryCompleted;

  const DeliveryPickupScreen({
    super.key,
    required this.deliveryId,
    this.onDeliveryCompleted,
  });

  @override
  State<DeliveryPickupScreen> createState() => _DeliveryPickupScreenState();
}

class _DeliveryPickupScreenState extends State<DeliveryPickupScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  // Changed to non-final variables so they can be updated
  Map<String, dynamic>? _orderData = {
    'diningHall': 'D2 (Dietrick Hall)',
    'dropOff': 'Hitt',
    'orderReference': 'PMH-2505-1422',
    'pickupInstructions': 'Ask at D2 south counter\nOrder #6324 under "Alex"',
  };

  Map<String, dynamic>? _requesterData = {
    'displayName': 'Hiren Sai',
    'rating': 4.2,
    'orderCount': 6,
  };

  @override
  void initState() {
    super.initState();
    // Uncomment this for actual data loading
    _loadDeliveryDetails();
  }

  Future<void> _loadDeliveryDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await user.reload();
      await user.getIdToken(true);
      print("User authenticated: ${user.uid}");

      DocumentSnapshot? orderDoc;
      String collectionName = '';
      final collectionsToTry = ['requests', 'deliveries'];

      // Try each collection in order
      for (final collection in collectionsToTry) {
        final doc =
            await _firestore
                .collection(collection)
                .doc(widget.deliveryId)
                .get();
        if (doc.exists) {
          orderDoc = doc;
          collectionName = collection;
          break;
        }
      }

      if (orderDoc == null || !orderDoc.exists) {
        throw Exception('Order not found in any collection');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      print("Successfully loaded order data from $collectionName");

      final requesterId = orderData['userId'] ?? orderData['requesterId'];
      if (requesterId == null) {
        throw Exception('Requester ID not found in order data');
      }

      final requesterDoc =
          await _firestore.collection('users').doc(requesterId).get();
      if (!requesterDoc.exists) {
        throw Exception('Requester profile not found');
      }

      final rawRequesterData = requesterDoc.data()!;
      print("Successfully loaded requester data: $rawRequesterData");

      final displayName =
          rawRequesterData['displayName'] ?? rawRequesterData['name'] ?? 'User';

      setState(() {
        _orderData = orderData;
        _requesterData = {...rawRequesterData, 'displayName': displayName};
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading delivery details: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading delivery details: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cancelPickup() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors1.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Cancel Pickup?',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Are you sure you want to cancel this pickup? This action cannot be undone.',
              style: TextStyle(color: AppColors1.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors1.textSecondary,
                ),
                child: const Text('No, keep it'),
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.red, Color(0xFFCC0000)],
                  ),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                  ),
                  child: const Text('Yes, cancel'),
                ),
              ),
            ],
          ),
    );

    if (shouldCancel == true) {
      try {
        // Try 'requests' collection first
        try {
          await _firestore
              .collection('requests')
              .doc(widget.deliveryId)
              .update({
                'status': 'pending',
                'deliveryPersonId': FieldValue.delete(),
                'acceptedAt': FieldValue.delete(),
              });
        } catch (e) {
          // Try 'deliveries' collection as fallback
          await _firestore
              .collection('deliveries')
              .doc(widget.deliveryId)
              .update({
                'status': 'available',
                'delivererId': null, // Using null as per your service file
                'updatedAt': FieldValue.serverTimestamp(),
              });
        }

        Navigator.pop(context); // Go back to delivery mode screen
      } catch (e) {
        print('Error canceling pickup: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error canceling pickup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmPickup() async {
    try {
      // ... your existing pickup confirmation code stays the same ...

      // Try 'requests' collection first
      try {
        await _firestore.collection('requests').doc(widget.deliveryId).update({
          'status': 'picked_up',
          'pickedUpAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Try 'deliveries' collection as fallback
        await _firestore.collection('deliveries').doc(widget.deliveryId).update(
          {'status': 'in_progress', 'updatedAt': FieldValue.serverTimestamp()},
        );
      }

      // ... your existing verification code logic stays the same ...
      String? verificationCode = _orderData?['verificationCode'];

      if (verificationCode == null) {
        print("Verification code missing, trying to fetch it directly");

        // First try 'requests' collection
        try {
          final freshDoc =
              await _firestore
                  .collection('requests')
                  .doc(widget.deliveryId)
                  .get();
          if (freshDoc.exists) {
            final freshData = freshDoc.data();
            verificationCode = freshData?['verificationCode'];
            print("Fetched verification code from requests: $verificationCode");
          }
        } catch (e) {
          print("Error fetching from requests: $e");
        }

        // If still null, try 'deliveries' collection
        if (verificationCode == null) {
          try {
            final freshDoc =
                await _firestore
                    .collection('deliveries')
                    .doc(widget.deliveryId)
                    .get();
            if (freshDoc.exists) {
              final freshData = freshDoc.data();
              verificationCode = freshData?['verificationCode'];
              print(
                "Fetched verification code from deliveries: $verificationCode",
              );
            }
          } catch (e) {
            print("Error fetching from deliveries: $e");
          }
        }
      }

      // If we still don't have a verification code, generate a random one
      if (verificationCode == null) {
        // Generate a random 4-digit code as fallback
        verificationCode =
            (1000 + DateTime.now().millisecond % 9000).toString();
        print("Generated random verification code: $verificationCode");

        // Try to save it back to the database for consistency
        try {
          await _firestore.collection('requests').doc(widget.deliveryId).update(
            {'verificationCode': verificationCode},
          );
          print("Saved generated verification code to database");
        } catch (e) {
          print("Error saving generated code: $e");
        }
      }

      print("Final verification code being passed: $verificationCode");

      // ✅ UPDATED: Navigate to DeliveryNavigationScreen with callback
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => DeliveryNavigationScreen(
                deliveryId: widget.deliveryId,
                verificationCode: verificationCode,
                onDeliveryCompleted:
                    widget.onDeliveryCompleted, // ✅ PASS CALLBACK THROUGH
              ),
        ),
      );
    } catch (e) {
      print('Error confirming pickup: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error confirming pickup: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _messageRequester() async {
    // Get the requester ID
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

    // Create or get conversation
    final ChatService chatService = ChatService();
    final String conversationId = await chatService.createConversation(
      requesterId,
      widget.deliveryId,
    );

    // Navigate to chat screen
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

  void _viewOrderScreenshot() {
    // Implementation for viewing order screenshot
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors1.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Order Screenshot',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: AppColors1.iconBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors1.borderGreen,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 48,
                        color: AppColors1.textSubtle,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors1.cancelButtonGradient,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: AppColors1.primaryGreen,
                ),
              )
              : SafeArea(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          // Header with back button - Redesigned
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Delivery Pickup',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: AppColors1.cancelButtonGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => Navigator.pop(context),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          'Back',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 8,
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

                          // Live Tracking Section - Integrated into page
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Tracking',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 24),

                                // Tracking progress
                                Container(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      // Starting point
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppColors1.primaryGreen,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors1.glowGreen,
                                              blurRadius: 16,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Progress line
                                      Expanded(
                                        child: Container(
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          height: 8,
                                          child: Stack(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Color(0xFF262626),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: 0.3,
                                                alignment: Alignment.centerLeft,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        AppColors1.primaryGreen,
                                                        Color(0xFF00D4AA),
                                                        Color(0xFF00A896),
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Destination point
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF666666),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 20),

                                // Labels
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _orderData?['diningHall'] ??
                                          'D2 (Dietrick Hall)',
                                      style: TextStyle(
                                        color: AppColors1.primaryGreen,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _orderData?['dropOff'] ?? 'Hitt',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 20),

                                // Status text
                                Text(
                                  'Deliverer heading to pickup location',
                                  style: TextStyle(
                                    color: AppColors1.primaryGreen,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Delivery Card - Optimized for mobile
                          Container(
                            margin: EdgeInsets.fromLTRB(16, 32, 16, 0),
                            padding: EdgeInsets.all(20),
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
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors1.borderGreen.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your Requester',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary.withOpacity(
                                      0.85,
                                    ),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors1.borderGreen
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _getInitials(
                                            _requesterData?['displayName'] ??
                                                'User',
                                          ),
                                          style: TextStyle(
                                            color: AppColors1.primaryGreen,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _requesterData?['displayName'] ??
                                                'User',
                                            style: TextStyle(
                                              color: AppColors1.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: AppColors1.primaryGreen,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '${(_requesterData?['averageRating'] ?? 4.2).toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  color: AppColors1.textPrimary
                                                      .withOpacity(0.75),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(width: 10),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${_requesterData?['ordersCompleted'] ?? 6} orders',
                                                  style: TextStyle(
                                                    color: AppColors1
                                                        .textPrimary
                                                        .withOpacity(0.75),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors:
                                              AppColors1.cancelButtonGradient,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: _messageRequester,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              'Message',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
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
                          ),

                          // Order Screenshot
                          Container(
                            margin: EdgeInsets.fromLTRB(16, 32, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order Screenshot',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                InkWell(
                                  onTap: _viewOrderScreenshot,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF262626).withOpacity(0.3),
                                      border: Border.all(
                                        color: AppColors1.borderGreen
                                            .withOpacity(0.3),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: AppColors1.primaryGreen,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.photo_camera,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Tap to view order screenshot',
                                          style: TextStyle(
                                            color: AppColors1.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Pickup Instructions
                          Container(
                            margin: EdgeInsets.fromLTRB(16, 32, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pickup Instructions',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  _orderData?['pickupInstructions'] ??
                                      'No instructions provided',
                                  style: TextStyle(
                                    color: AppColors1.textPrimary.withOpacity(
                                      0.85,
                                    ),
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Add bottom spacing for the floating button
                          SizedBox(height: 120),
                        ],
                      ),
                    ),

                    // Floating Pickup Button - Optimized size
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
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
                            onTap: _confirmPickup,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text(
                                  'Picked Up',
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors1.textSubtle,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors1.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';

    final nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }

    return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
  }
}
