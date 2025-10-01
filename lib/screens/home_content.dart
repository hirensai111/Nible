import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/colors.dart';
import '../models/delivery.dart';
import '../models/user.dart';
import '../widgets/delivery_card.dart';
import 'request_pickup_screen.dart';
import 'delivery_mode_screen.dart';
import 'subscription_screen.dart';
import '../services/auth_service.dart';
import 'wallet_screen.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  // Add this helper function here
  Color rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

  final _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pastOrders = [];
  bool _isLoadingOrders = true;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupOrdersListener();
  }

  @override
  void dispose() {
    // Cancel the subscription BEFORE calling super.dispose()
    _ordersSubscription?.cancel();
    _ordersSubscription = null;
    super.dispose();
  }

  Future<void> _loadUserData() async {
    // Check if widget is still mounted before starting
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? userData = await _authService.getUserData();

      // Check mounted again after async operation
      if (!mounted) return;

      setState(() {
        _userData = userData;
      });
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      // Always check mounted before setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupOrdersListener() {
    // Check if widget is mounted before starting
    if (!mounted) return;

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      // Get current user's ID
      final currentUserId = _authService.getCurrentUserId();
      if (currentUserId == null) {
        if (mounted) {
          setState(() {
            _isLoadingOrders = false;
          });
        }
        return;
      }

      final ordersStream =
          _firestore
              .collection('requests')
              .where('userId', isEqualTo: currentUserId)
              .where('status', isEqualTo: 'completed')
              .orderBy('completedAt', descending: true)
              .limit(3)
              .snapshots();

      _ordersSubscription = ordersStream.listen(
        (snapshot) {
          // Double-check mounted before processing data
          if (!mounted) return;

          final orders =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'orderNumber': data['orderNumber'] ?? 'N/A',
                  'diningHall': data['diningHall'] ?? 'Unknown',
                  'dropOff': data['dropOff'] ?? 'Unknown',
                  'totalFee':
                      (data['totalFee'] is num)
                          ? (data['totalFee'] as num).toDouble()
                          : 0.0,
                  'completedAt': data['completedAt'],
                  'tags': data['tags'] ?? [],
                  'deliveryStatus': data['deliveryStatus'] ?? 'completed',
                };
              }).toList();

          // Check mounted again before setState
          if (mounted) {
            setState(() {
              _pastOrders = orders;
              _isLoadingOrders = false;
            });
          }
        },
        onError: (error) {
          print('Error in orders stream: $error');
          // Check mounted before setState in error handler too
          if (mounted) {
            setState(() {
              _isLoadingOrders = false;
            });
          }
        },
        // Add cancelOnError to prevent stream from continuing after errors
        cancelOnError: false,
      );
    } catch (e) {
      print('Error setting up orders listener: $e');
      // Check mounted before setState in catch block
      if (mounted) {
        setState(() {
          _isLoadingOrders = false;
        });
      }
    }
  }

  // Helper method to format timestamp
  String _formatOrderDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is Map) {
        // Handle Firestore timestamp map format
        final seconds = timestamp['_seconds'] ?? 0;
        final nanoseconds = timestamp['_nanoseconds'] ?? 0;
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds ~/ 1000000),
        );
      } else {
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      print('Error formatting date: $e');
      return 'N/A';
    }
  }

  // Helper methods for subscription display
  String _getSubscriptionPlanName() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return 'Campus Access';
      case 'delivery_plus':
        return 'Delivery Plus';
      case 'all_access':
        return 'All Access';
      case 'free':
      case null:
        return 'Free Plan';
      default:
        return 'Free Plan';
    }
  }

  String _getSubscriptionDescription() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return 'Meal plan assistance';
      case 'delivery_plus':
        return 'Every 8th order free';
      case 'all_access':
        return 'Every 5th order free';
      case 'free':
      case null:
        return '\$3.00 per delivery';
      default:
        return '\$3.00 per delivery';
    }
  }

  IconData _getSubscriptionIcon() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return Icons.school;
      case 'delivery_plus':
        return Icons.flash_on;
      case 'all_access':
        return Icons.star;
      default:
        return Icons.person;
    }
  }

  String _getSubscriptionProgress() {
    final subscriptionTier = _userData?['subscriptionTier'];
    final usage = _userData?['subscriptionUsage'] as Map<String, dynamic>?;

    if (subscriptionTier == null || subscriptionTier == 'free') {
      return 'Manage Plan';
    }

    if (subscriptionTier == 'all_access') {
      final freeRemaining = usage?['freeOrdersRemaining'] ?? 0;
      return '$freeRemaining free left';
    } else if (subscriptionTier == 'delivery_plus') {
      final ordersThisMonth = usage?['ordersThisMonth'] ?? 0;
      final toGo = 8 - (ordersThisMonth % 8);
      return '$toGo more to go';
    } else if (subscriptionTier == 'campus_access') {
      return 'Active plan';
    }

    return 'Manage Plan';
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    Color iconColor = Colors.white,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1A1A1A), const Color(0xFF111111)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black45),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Add this helper method with your other helper methods in _HomeContentState class
  Widget _buildDiningHallTile({
    required String name,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image doesn't exist
                    return Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(
                        Icons.restaurant,
                        color: Colors.white54,
                        size: 40,
                      ),
                    );
                  },
                ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // Text overlay
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMediumScreen = screenWidth < 380;
    double responsiveFont(double size) => isMediumScreen ? size * 0.85 : size;

    if (!mounted) return const SizedBox.shrink();

    // Show loading indicator for the entire screen
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors1.primaryGreen),
        ),
      );
    }

    UserModel user = UserModel(
      name: _userData?['name'] ?? 'User',
      walletBalance: _userData?['credits'] ?? 0.0,
      deliveriesMade: _userData?['deliveriesMade'] ?? 0,
      averageRating: _userData?['averageRating'] ?? 0.0,
      totalEarned: _userData?['totalEarned'] ?? 0.0,
      deliveriesUntilHokieHero: _userData?['deliveriesUntilHokieHero'] ?? 3,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              flex: (_userData?['deliveryAccess'] == true) ? 1 : 2,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RequestPickupScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: Text(
                    'Request',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: responsiveFont(18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (_userData?['deliveryAccess'] == true) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/delivery-mode');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                    ),
                    child: Text(
                      'Deliver',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: responsiveFont(18),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Greeting
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hi, ${user.name.split(' ')[0]}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsiveFont(52),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF0A0A0A),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subscription Card
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubscriptionScreen(),
                            ),
                          ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        height: 130,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              rgba(0, 77, 64, 0.8),
                              rgba(0, 40, 35, 0.85),
                              rgba(0, 0, 0, 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0x3300FF88),
                            width: 1,
                          ),
                        ),

                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x1A00FF88),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.bolt,
                                  color: Color(0xFF00FF88),
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getSubscriptionPlanName(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: responsiveFont(20),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _getSubscriptionDescription(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: responsiveFont(14),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: 0.625,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00FF88),
                                              Color(0xFF00D4AA),
                                              Color(0xFF00A896),
                                              Color(0x4D00A896),
                                              Colors.transparent,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getSubscriptionProgress(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: responsiveFont(12),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Order from here section
                    // Order from here section - Replace your existing section with this
                    Container(
                      margin: const EdgeInsets.only(bottom: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order from here',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: responsiveFont(22),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 15),

                          // First row of dining halls
                          Row(
                            children: [
                              _buildDiningHallTile(
                                name: 'Owens Hall',
                                imagePath: 'assets/images/owens_hall1.jpg',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RequestPickupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildDiningHallTile(
                                name: 'Perry Place',
                                imagePath: 'assets/images/perry_place1.jpg',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RequestPickupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Second row of dining halls
                          Row(
                            children: [
                              _buildDiningHallTile(
                                name: 'Turners Place',
                                imagePath: 'assets/images/turner_place1.png',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RequestPickupScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildDiningHallTile(
                                name: 'West End',
                                imagePath: 'assets/images/westend1.jpg',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const RequestPickupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Recent Orders
                    // Recent Orders
                    Text(
                      'Recent Requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsiveFont(22),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 15),

                    _isLoadingOrders
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00FF88),
                          ),
                        )
                        : _pastOrders.isEmpty
                        ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No past orders found',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        : Column(
                          children:
                              _pastOrders.map((order) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${order['diningHall']}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: responsiveFont(16),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatOrderDate(
                                                order['completedAt'],
                                              ),
                                              style: TextStyle(
                                                color: const Color(0xFF666666),
                                                fontSize: responsiveFont(13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '\$${order['totalFee'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: responsiveFont(15),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),

                    const SizedBox(height: 25),

                    // Stats Section
                    if (_userData?['deliveryAccess'] == true) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Stats',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsiveFont(18),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildStatCard(
                                  icon: Icons.local_shipping,
                                  label: 'Deliveries',
                                  value: '${user.deliveriesMade}',
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  icon: Icons.star,
                                  label: 'Rating',
                                  value:
                                      '${user.averageRating.toStringAsFixed(1)}★',
                                  iconColor: Colors.greenAccent,
                                ),
                                const SizedBox(width: 10),
                                _buildStatCard(
                                  icon: Icons.attach_money,
                                  label: 'Earned',
                                  value: '\$${user.totalEarned.toInt()}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
