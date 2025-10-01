import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nible/models/user.dart';
import '../constants/colors.dart';
import '../models/delivery.dart';
import 'delivery_pickup_screen.dart';
import '../services/delivery_service.dart';

class DeliveryModeScreen extends StatefulWidget {
  const DeliveryModeScreen({super.key});

  @override
  State<DeliveryModeScreen> createState() => _DeliveryModeScreenState();
}

class _DeliveryModeScreenState extends State<DeliveryModeScreen>
    with SingleTickerProviderStateMixin {
  // Use the delivery service instead of local state
  final DeliveryService _deliveryService = DeliveryService();
  double todaysEarnings = 0.0;
  bool _initialPromptShown = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Available requests from Firebase
  List<DeliveryModel> _availableRequests = [];
  bool _isLoadingRequests = true;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  // Animation controller for toggle switch
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller based on current delivery state
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _deliveryService.isDelivering ? 1.0 : 0.0,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Listen to delivery service changes
    _deliveryService.addListener(_onDeliveryStateChanged);

    // Load today's earnings
    _loadTodaysEarnings();

    // If currently delivering, set up requests
    if (_deliveryService.isDelivering) {
      _loadAvailableRequests();
    }
  }

  void _onDeliveryStateChanged() {
    if (mounted) {
      setState(() {
        // Update animation based on delivery state
        if (_deliveryService.isDelivering) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    }
  }

  @override
  void dispose() {
    _deliveryService.removeListener(_onDeliveryStateChanged);
    _requestsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTodaysEarnings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("No user logged in, earnings set to 0");
        return;
      }

      // Get today's date range
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart
          .add(Duration(days: 1))
          .subtract(Duration(milliseconds: 1));

      print("Loading earnings for ${user.uid} from $todayStart to $todayEnd");

      // Query completed deliveries for today
      final snapshot =
          await _firestore
              .collection('requests')
              .where('deliveryPersonId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'completed')
              .where(
                'completedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .where(
                'completedAt',
                isLessThanOrEqualTo: Timestamp.fromDate(todayEnd),
              )
              .get();

      // Calculate earnings as $2.00 per completed delivery
      double earnings = snapshot.docs.length * 2.00;

      print(
        "Found ${snapshot.docs.length} completed deliveries today = \$${earnings.toStringAsFixed(2)}",
      );

      if (mounted) {
        setState(() {
          todaysEarnings = earnings;
        });
      }
    } catch (e) {
      print('Error loading today\'s earnings: $e');
    }
  }

  // Load available requests from Firestore
  void _loadAvailableRequests() {
    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("❌ No user logged in");
        setState(() {
          _isLoadingRequests = false;
        });
        return;
      }

      print("✅ Current user ID: ${user.uid}");

      final requestsStream =
          _firestore
              .collection('requests')
              .where('status', isEqualTo: 'pending')
              .where('userId', isNotEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .snapshots();

      _requestsSubscription = requestsStream.listen(
        (snapshot) {
          print("📦 Query returned ${snapshot.docs.length} documents");

          final requests =
              snapshot.docs.map((doc) {
                final data = doc.data();
                print(
                  "📄 Processing doc: ${doc.id} - ${data['diningHall']} to ${data['dropOff']}",
                );

                return DeliveryModel(
                  id: doc.id,
                  pickupLocation: data['diningHall'] ?? 'Unknown',
                  dropoffLocation: data['dropOff'] ?? 'Unknown',
                  itemCount: 1,
                  distance: 0.5,
                  estimatedTime: 15,
                  fee: 2.00,
                );
              }).toList();

          print("✅ Created ${requests.length} DeliveryModel objects");

          if (mounted) {
            setState(() {
              _availableRequests = requests;
              _isLoadingRequests = false;
            });
          }
        },
        onError: (error) {
          print('❌ Error in requests stream: $error');
          if (mounted) {
            setState(() {
              _isLoadingRequests = false;
            });
          }
        },
      );
    } catch (e) {
      print('❌ Error setting up requests listener: $e');
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  void _onDeliveryCompleted(double earnedAmount) {
    print(
      "Delivery completed! Adding \$${earnedAmount.toStringAsFixed(2)} to today's earnings",
    );

    setState(() {
      todaysEarnings += earnedAmount;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Today\'s earnings updated: +\$${earnedAmount.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: AppColors1.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _acceptDelivery(DeliveryModel delivery) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final freshDoc = await transaction.get(
          _firestore.collection('requests').doc(delivery.id),
        );

        if (!freshDoc.exists || freshDoc.data()?['status'] == 'accepted') {
          throw Exception('Delivery is no longer available');
        }

        transaction.update(_firestore.collection('requests').doc(delivery.id), {
          'status': 'accepted',
          'deliveryPersonId': user.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      setState(() {
        _availableRequests.removeWhere((req) => req.id == delivery.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delivery accepted! Preparing details...',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: AppColors1.primaryGreen,
          duration: Duration(seconds: 1),
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => DeliveryPickupScreen(
                deliveryId: delivery.id,
                onDeliveryCompleted: _onDeliveryCompleted,
              ),
        ),
      );
    } catch (e) {
      print('Error accepting delivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error accepting delivery: ${e.toString()}',
            style: TextStyle(color: AppColors1.textPrimary),
          ),
          backgroundColor: AppColors1.cardColor,
        ),
      );
    }
  }

  void _toggleDeliveryMode() async {
    if (_deliveryService.isDelivering) {
      // Show confirmation only when user toggles OFF
      final shouldStop = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              backgroundColor: AppColors1.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Stop Delivering?',
                style: TextStyle(
                  color: AppColors1.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to stop accepting deliveries?',
                style: TextStyle(color: AppColors1.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors1.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: AppColors1.primaryGreen,
                  ),
                  child: const Text('Yes, stop'),
                ),
              ],
            ),
      );

      if (shouldStop == true) {
        _deliveryService.stopDelivering();
        _requestsSubscription?.cancel();
        setState(() {
          _availableRequests.clear();
        });
      }
    } else {
      // Turn ON delivery mode
      _deliveryService.startDelivering();
      _loadAvailableRequests();
    }
  }

  String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  // Custom toggle widget with Nible colors
  Widget _buildCustomToggle() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _toggleDeliveryMode,
          child: Container(
            width: 54,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color:
                  _deliveryService.isDelivering
                      ? AppColors1.primaryGreen
                      : AppColors1.iconBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color:
                      _deliveryService.isDelivering
                          ? AppColors1.glowGreen
                          : Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedAlign(
              alignment:
                  _animation.value > 0.5
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
              duration: Duration(milliseconds: 200),
              child: Container(
                width: 22,
                height: 22,
                margin: EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color:
                      _deliveryService.isDelivering
                          ? Colors.black
                          : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child:
                    _deliveryService.isDelivering
                        ? Icon(
                          Icons.delivery_dining,
                          color: AppColors1.primaryGreen,
                          size: 14,
                        )
                        : Icon(
                          Icons.pause,
                          color: AppColors1.textSubtle,
                          size: 14,
                        ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors1.surfaceColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 360;
            final isMediumScreen = constraints.maxWidth < 600;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        isSmallScreen ? 16 : 30,
                        16,
                        10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Deliverer Mode',
                              style: TextStyle(
                                color: AppColors1.textPrimary,
                                fontSize: isSmallScreen ? 32 : 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors1.textPrimary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.close,
                                color: AppColors1.textPrimary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Earnings Card
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: AppColors1.deliveryCardGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: AppColors1.borderGreen.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Today's Earnings:",
                                  style: TextStyle(
                                    color: AppColors1.textPrimary,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${todaysEarnings.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppColors1.primaryGreen,
                                  fontSize: isSmallScreen ? 22 : 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                'Active Status',
                                style: TextStyle(
                                  color: AppColors1.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors1.borderGreen.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: AppColors1.primaryGreen,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Time Active: ${formatDuration(_deliveryService.elapsed)}',
                                          style: TextStyle(
                                            color: AppColors1.textPrimary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildCustomToggle(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Pickup Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Available Pickups',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pickup List
                    _deliveryService.isDelivering
                        ? _isLoadingRequests
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: CircularProgressIndicator(
                                  color: AppColors1.primaryGreen,
                                ),
                              ),
                            )
                            : _availableRequests.isEmpty
                            ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      size: 48,
                                      color: AppColors1.textSubtle,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No requests available',
                                      style: TextStyle(
                                        color: AppColors1.textSubtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _availableRequests.length,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemBuilder: (context, index) {
                                final delivery = _availableRequests[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors1.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${delivery.pickupLocation} → ${delivery.dropoffLocation}',
                                              style: TextStyle(
                                                color: AppColors1.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                _buildInfoChip(
                                                  Icons.inventory_2,
                                                  '${delivery.itemCount} item',
                                                ),
                                                _buildInfoChip(
                                                  Icons.location_on,
                                                  '${delivery.distance} mi',
                                                ),
                                                _buildInfoChip(
                                                  Icons.access_time_filled,
                                                  '${delivery.estimatedTime} min',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors1.primaryGreen,
                                          borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(12),
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap:
                                              () => _acceptDelivery(delivery),
                                          child: Center(
                                            child: Text(
                                              'Accept Delivery',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                        : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.delivery_dining,
                                  color: AppColors1.textSubtle,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Toggle on to start delivering',
                                  style: TextStyle(
                                    color: AppColors1.textSubtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors1.iconBackgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors1.textSubtle, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: AppColors1.textSubtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
