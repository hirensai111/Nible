import 'package:flutter/material.dart';
import 'package:nible/screens/chat_screen.dart';
import 'package:nible/screens/delivery_navigation_screen.dart';
import 'package:nible/screens/delivery_pickup_screen.dart';
import 'package:nible/screens/order_tracking_screen.dart';
import 'package:nible/services/chat_service.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  late TabController _tabController;
  bool hasDeliveryAccess = false;
  bool _isLoading = true;

  // Map dining halls to their image assets
  final Map<String, String> diningHallImages = {
    'Dietrick Hall': 'assets/images/dietrick_hall.jpg',
    'Owens Food Court': 'assets/images/owens_hall.jpg',
    'Perry Place': 'assets/images/perry_place.jpg',
    'Turners Place': 'assets/images/turner_place.jpg',
    'Owens HG': 'assets/images/owens_hg.jpg',
    'West End': 'assets/images/westend.jpg',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkDeliveryAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkDeliveryAccess() async {
    try {
      final userData = await _authService.getUserData();
      if (mounted) {
        setState(() {
          hasDeliveryAccess = userData?['deliveryAccess'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking delivery access: $e');
      if (mounted) {
        setState(() {
          hasDeliveryAccess = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors1.backgroundColor, // Pure black background
      body: SafeArea(
        child:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors1.primaryGreen,
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        hasDeliveryAccess ? 'My Orders' : 'My Requests',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Conditional Tab Bar - only show if user has delivery access
                    if (hasDeliveryAccess) ...[
                      // Custom Tab Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 45,
                          decoration: BoxDecoration(
                            color: AppColors1.iconBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors1.borderGreen,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // My Requests Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    _tabController.animateTo(0);
                                    setState(() {});
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient:
                                          _tabController.index == 0
                                              ? LinearGradient(
                                                colors: [
                                                  AppColors1.primaryGreen,
                                                  AppColors1.primaryGreen
                                                      .withOpacity(0.8),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              )
                                              : null,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        bottomLeft: Radius.circular(11),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'My Requests',
                                        style: TextStyle(
                                          color:
                                              _tabController.index == 0
                                                  ? AppColors1.backgroundColor
                                                  : AppColors1.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // My Deliveries Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    _tabController.animateTo(1);
                                    setState(() {});
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient:
                                          _tabController.index == 1
                                              ? LinearGradient(
                                                colors: [
                                                  AppColors1.primaryGreen
                                                      .withOpacity(0.8),
                                                  AppColors1.primaryGreen,
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              )
                                              : null,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(11),
                                        bottomRight: Radius.circular(11),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'My Deliveries',
                                        style: TextStyle(
                                          color:
                                              _tabController.index == 1
                                                  ? AppColors1.backgroundColor
                                                  : AppColors1.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Tab Content
                    Expanded(
                      child:
                          hasDeliveryAccess
                              ? TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildRequestsTab(),
                                  _buildDeliveriesTab(),
                                ],
                              )
                              : _buildRequestsTab(),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseAuth.instance.currentUser == null
              ? null
              : _firestore
                  .collection('requests')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return Center(
            child: Text(
              'Please sign in to view orders',
              style: TextStyle(color: AppColors1.textSecondary, fontSize: 14),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: CircularProgressIndicator(color: AppColors1.primaryGreen),
          );
        }

        final docs = snapshot.data!.docs;

        final ongoing = <Map<String, dynamic>>[];
        final past = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          final status = data['status']?.toString() ?? '';
          if (status == 'pending' ||
              status == 'accepted' ||
              status == 'picked_up') {
            ongoing.add(data);
          } else {
            past.add(data);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Ongoing Requests Header
            Text(
              'Ongoing Requests',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (ongoing.isEmpty)
              _buildEmptyState(
                'No ongoing requests',
                'Your current order requests will appear here',
              ),
            ...ongoing
                .map(
                  (order) => _buildOrderCard(
                    order,
                    isOngoing: true,
                    isDelivery: false,
                  ),
                )
                .toList(),

            const SizedBox(height: 16),
            // Past Requests Header
            Text(
              'Past Requests',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (past.isEmpty)
              _buildEmptyState(
                'No past requests',
                'Your request history will appear here',
              ),
            ...past
                .map((order) => _buildOrderCard(order, isDelivery: false))
                .toList(),
          ],
        );
      },
    );
  }

  Widget _buildDeliveriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseAuth.instance.currentUser == null
              ? null
              : _firestore
                  .collection('requests')
                  .where(
                    'deliveryPersonId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return Center(
            child: Text(
              'Please sign in to view deliveries',
              style: TextStyle(color: AppColors1.textSecondary, fontSize: 14),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: CircularProgressIndicator(color: AppColors1.primaryGreen),
          );
        }

        final docs = snapshot.data!.docs;

        final ongoing = <Map<String, dynamic>>[];
        final past = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;

          final status = data['status']?.toString() ?? '';
          if (status == 'accepted' || status == 'picked_up') {
            ongoing.add(data);
          } else if (status == 'completed' || status == 'cancelled') {
            past.add(data);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Ongoing Deliveries Header
            Text(
              'Ongoing Deliveries',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (ongoing.isEmpty)
              _buildEmptyState(
                'No ongoing deliveries',
                'Deliveries you\'ve accepted will appear here',
              ),
            ...ongoing
                .map(
                  (order) =>
                      _buildOrderCard(order, isOngoing: true, isDelivery: true),
                )
                .toList(),

            const SizedBox(height: 16),
            // Completed Deliveries Header
            Text(
              'Completed Deliveries',
              style: TextStyle(
                color: AppColors1.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (past.isEmpty)
              _buildEmptyState(
                'No completed deliveries',
                'Your delivery history will appear here',
              ),
            ...past
                .map((order) => _buildOrderCard(order, isDelivery: true))
                .toList(),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors1.borderGreen, width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long, color: AppColors1.textSubtle, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(color: AppColors1.textSubtle, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order, {
    bool isOngoing = false,
    bool isDelivery = false,
  }) {
    final status = order['status'] ?? 'pending';
    final orderRef = order['orderNumber'] ?? 'N/A';
    final diningHall = order['diningHall'] ?? 'Unknown';
    final dropOff = order['dropOff'] ?? 'Unknown';

    // Show image tile for orders that are not completed or cancelled
    final showImageTile = status != 'completed' && status != 'cancelled';

    return GestureDetector(
      onTap: () {
        if (isDelivery) {
          switch (status) {
            case 'accepted':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          DeliveryPickupScreen(deliveryId: order['id']),
                ),
              );
              break;
            case 'picked_up':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          DeliveryNavigationScreen(deliveryId: order['id']),
                ),
              );
              break;
            default:
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingScreen(order: order),
                ),
              );
              break;
          }
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingScreen(order: order),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isDelivery
                    ? AppColors1.deliveryCardGradient.take(2).toList()
                    : [
                      AppColors1.deliveryCardGradient[1],
                      AppColors1.deliveryCardGradient[0],
                    ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors1.borderGreen, width: 1),
          boxShadow:
              isOngoing
                  ? [
                    BoxShadow(
                      color: AppColors1.glowGreen,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          children: [
            // Image tile for non-completed orders
            if (showImageTile)
              _buildOrderImageTile(diningHall, orderRef, status),

            // Order details
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: showImageTile ? 10 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showImageTile) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Order #$orderRef',
                            style: const TextStyle(
                              color: AppColors1.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(status).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatStatus(status),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    isDelivery
                        ? 'From $diningHall to $dropOff'
                        : 'Delivery to $dropOff',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (isOngoing) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors1.progressGradient.take(3).toList(),
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderImageTile(
    String diningHall,
    String orderRef,
    String status,
  ) {
    final imagePath = diningHallImages[diningHall];

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or placeholder
            if (imagePath != null)
              Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder();
                },
              )
            else
              _buildImagePlaceholder(),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),

            // Text overlay
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    diningHall,
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #$orderRef',
                        style: TextStyle(
                          color: AppColors1.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors1.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors1.primaryGreen.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            color: AppColors1.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors1.iconBackgroundColor,
      child: Center(
        child: Icon(Icons.restaurant, color: AppColors1.textSubtle, size: 40),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors1.textSubtle;
      case 'accepted':
      case 'picked_up':
        return AppColors1.primaryGreen;
      case 'completed':
        return AppColors1.primaryGreen;
      case 'cancelled':
        return Colors.red;
      default:
        return AppColors1.textSubtle;
    }
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
