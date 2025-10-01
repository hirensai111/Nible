import 'package:flutter/material.dart';
import 'package:nible/screens/profile_info_screen.dart';
import '../constants/colors.dart';
import 'splash_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:nible/screens/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool hasDeliveryAccess = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupUserListener();
  }

  void _setupUserListener() {
    final user = _authService.currentUser;
    if (user == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;
          if (snapshot.exists) {
            setState(() {
              _userData = snapshot.data();
              hasDeliveryAccess = _userData?['deliveryAccess'] ?? false;
              _isLoading = false;
            });
          }
        });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? userData = await _authService.getUserData();
      if (!mounted) return;
      setState(() {
        _userData = userData;
        hasDeliveryAccess = userData?['deliveryAccess'] ?? false;
      });
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeliveryRegistrationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors1.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors1.borderGreen, width: 1),
            ),
            title: const Text(
              'Become a Deliverer',
              style: TextStyle(color: AppColors1.textPrimary),
            ),
            content: Text(
              'To become a deliverer, please contact our support team. We\'ll review your application and enable delivery access for your account.',
              style: TextStyle(color: AppColors1.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors1.textTertiary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Please contact support at support@nible.com',
                      ),
                      backgroundColor: AppColors1.primaryGreen,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors1.primaryGreen,
                  foregroundColor: AppColors1.backgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Contact Support'),
              ),
            ],
          ),
    );
  }

  void _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors1.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors1.borderGreen, width: 1),
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors1.textPrimary),
            ),
            content: Text(
              'Are you sure you want to sign out?',
              style: TextStyle(color: AppColors1.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors1.textTertiary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Yes, Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldSignOut == true) {
      try {
        _userSubscription?.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isFirstLogin', false);
        await prefs.clear();
        await _authService.signOut();

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );

        print('✅ Successfully signed out');
      } catch (e) {
        print('❌ Error signing out: $e');
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getInitials(String fullName) {
    List<String> names = fullName.split(' ');
    String initials = '';

    if (names.isNotEmpty && names[0].isNotEmpty) {
      initials += names[0][0];
    }

    if (names.length > 1 && names[1].isNotEmpty) {
      initials += names[1][0];
    }

    return initials.toUpperCase();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'August 2023';

    DateTime date;
    if (timestamp is DateTime) {
      date = timestamp;
    } else {
      date = timestamp.toDate();
    }

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _getSubscriptionBadgeText() {
    final subscriptionTier = _userData?['subscriptionTier'];
    switch (subscriptionTier) {
      case 'campus_access':
        return 'CAMPUS';
      case 'delivery_plus':
        return 'DELIVERY+';
      case 'all_access':
        return 'ALL ACCESS';
      default:
        return 'FREE';
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  int _calculateInProgressOrders() {
    final placed = _userData?['ordersPlaced'] ?? 0;
    final completed = _userData?['ordersCompleted'] ?? 0;
    final inProgress = placed - completed;
    return inProgress < 0 ? 0 : inProgress;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 410;

    final profileFontSize = isSmallScreen ? 42.0 : 44.0;
    final nameFontSize = isSmallScreen ? 18.0 : 20.0;
    final avatarSize = isSmallScreen ? 55.0 : 65.0;
    final initialsSize = isSmallScreen ? 20.0 : 24.0;
    final sectionFontSize = isSmallScreen ? 18.0 : 20.0;
    final statValueSize = isSmallScreen ? 18.0 : 20.0;
    final mainPadding = isSmallScreen ? 12.0 : 14.0;
    final cardPadding = isSmallScreen ? 14.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor, // Pure black background
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(mainPadding),
          children: [
            // Profile header
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: profileFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Profile Info Card
            Container(
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors1.deliveryCardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors1.borderGreen, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors1.glowGreen,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors1.primaryGreen,
                        ),
                      )
                      : Row(
                        children: [
                          // Avatar with online indicator
                          Stack(
                            children: [
                              Container(
                                width: avatarSize,
                                height: avatarSize,
                                decoration: BoxDecoration(
                                  color: AppColors1.iconBackgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    avatarSize / 2,
                                  ),
                                  border: Border.all(
                                    color: AppColors1.borderGreen,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(_userData?['name'] ?? 'User'),
                                    style: TextStyle(
                                      color: AppColors1.primaryGreen,
                                      fontSize: initialsSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Online indicator
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  width: isSmallScreen ? 14 : 18,
                                  height: isSmallScreen ? 14 : 18,
                                  decoration: BoxDecoration(
                                    color: AppColors1.primaryGreen,
                                    borderRadius: BorderRadius.circular(
                                      isSmallScreen ? 7 : 9,
                                    ),
                                    border: Border.all(
                                      color: AppColors1.backgroundColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors1.glowGreen,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name with subscription badge
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _userData?['name'] ?? 'User',
                                        style: TextStyle(
                                          color: AppColors1.textPrimary,
                                          fontSize: nameFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 6 : 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors1.primaryGreen
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors1.borderGreen,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _getSubscriptionBadgeText(),
                                        style: TextStyle(
                                          color: AppColors1.primaryGreen,
                                          fontSize: isSmallScreen ? 9 : 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['email'] ?? 'user@example.com',
                                  style: TextStyle(
                                    color: AppColors1.textSecondary,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                Text(
                                  'Member since ${_formatDate(_userData?['createdAt'])}',
                                  style: TextStyle(
                                    color: AppColors1.textTertiary,
                                    fontSize: isSmallScreen ? 9 : 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Virginia Tech',
                                  style: TextStyle(
                                    color: AppColors1.textTertiary,
                                    fontSize: isSmallScreen ? 9 : 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // Stats Section
            _buildSectionHeader('Stats', sectionFontSize),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors1.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors1.borderGreen, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasDeliveryAccess) ...[
                    // Deliveries Section
                    Padding(
                      padding: EdgeInsets.only(left: cardPadding, top: 16),
                      child: Text(
                        'Deliveries',
                        style: TextStyle(
                          color: AppColors1.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: cardPadding,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItemMockup(
                            'Completed',
                            '${_userData?['deliveriesMade'] ?? '0'}',
                            color: AppColors1.textPrimary,
                            isSmallScreen: isSmallScreen,
                            statValueSize: statValueSize,
                          ),
                          _buildDivider(),
                          _statItemMockup(
                            'Rating',
                            '${_userData?['averageRating']?.toStringAsFixed(1) ?? '0.0'}',
                            hasStar: true,
                            color: AppColors1.primaryGreen,
                            isSmallScreen: isSmallScreen,
                            statValueSize: statValueSize,
                          ),
                          _buildDivider(),
                          _statItemMockup(
                            'Total Reviews',
                            '${_userData?['totalRatings'] ?? '0'}',
                            color: AppColors1.textPrimary,
                            isSmallScreen: isSmallScreen,
                            statValueSize: statValueSize,
                          ),
                        ],
                      ),
                    ),
                    _horizontalDivider(),
                  ],

                  // Orders Section
                  Padding(
                    padding: EdgeInsets.only(left: cardPadding, top: 16),
                    child: Text(
                      'Orders',
                      style: TextStyle(
                        color: AppColors1.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: cardPadding,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statItemMockup(
                          'Placed',
                          '${_userData?['ordersPlaced'] ?? '0'}',
                          color: AppColors1.textPrimary,
                          isSmallScreen: isSmallScreen,
                          statValueSize: statValueSize,
                        ),
                        _buildDivider(),
                        _statItemMockup(
                          'Completed',
                          '${_userData?['ordersCompleted'] ?? '0'}',
                          color: AppColors1.textPrimary,
                          isSmallScreen: isSmallScreen,
                          statValueSize: statValueSize,
                        ),
                        _buildDivider(),
                        _statItemMockup(
                          'In Progress',
                          '${_calculateInProgressOrders()}',
                          color: AppColors1.primaryGreen,
                          isSmallScreen: isSmallScreen,
                          statValueSize: statValueSize,
                        ),
                      ],
                    ),
                  ),

                  _horizontalDivider(),

                  // Achievements Section
                  Padding(
                    padding: EdgeInsets.only(left: cardPadding, top: 16),
                    child: Text(
                      'Achievements',
                      style: TextStyle(
                        color: AppColors1.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _badgeMockup(
                          'HOKIE HERO',
                          'H',
                          unlocked: (_userData?['deliveriesMade'] ?? 0) >= 20,
                          isSmallScreen: isSmallScreen,
                        ),
                        _badgeMockup(
                          'PERFECT 5 STARS',
                          '5★',
                          unlocked: (_userData?['averageRating'] ?? 0) >= 5.0,
                          isSmallScreen: isSmallScreen,
                        ),
                        _badgeMockup(
                          'SPEED DEMON',
                          'S',
                          unlocked: (_userData?['fastDeliveries'] ?? 0) >= 10,
                          isSmallScreen: isSmallScreen,
                        ),
                        _badgeMockup(
                          'REGULAR',
                          'R',
                          unlocked: (_userData?['ordersPlaced'] ?? 0) >= 15,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // Account Section
            _buildSectionHeader('Account', sectionFontSize),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors1.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors1.borderGreen, width: 1),
              ),
              child: Column(
                children: [
                  _settingsItemMockup(
                    'Premium Plans',
                    Icons.workspace_premium,
                    isSmallScreen: isSmallScreen,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                  _settingsItemDivider(),
                  _settingsItemMockup(
                    'Personal Information',
                    Icons.person,
                    isSmallScreen: isSmallScreen,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ProfileInfoScreen(userData: _userData),
                        ),
                      );

                      if (result == true) {
                        _loadUserData();
                      }
                    },
                  ),

                  if (!hasDeliveryAccess) ...[
                    _settingsItemDivider(),
                    _settingsItemMockup(
                      'Become a Deliverer',
                      Icons.delivery_dining,
                      isSmallScreen: isSmallScreen,
                      onTap: _showDeliveryRegistrationDialog,
                    ),
                  ],

                  _settingsItemDivider(),
                  _settingsItemMockup(
                    'Customer Support',
                    Icons.support_agent,
                    isSmallScreen: isSmallScreen,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              backgroundColor: AppColors1.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: AppColors1.borderGreen,
                                  width: 1,
                                ),
                              ),
                              title: const Text(
                                'Customer Support',
                                style: TextStyle(color: AppColors1.textPrimary),
                              ),
                              content: Text(
                                'Need help? Contact our support team:\n\nEmail: support@nible.com\nPhone: (540) 555-NIBLE',
                                style: TextStyle(
                                  color: AppColors1.textSecondary,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Close',
                                    style: TextStyle(
                                      color: AppColors1.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),

            // Sign Out Button
            Container(
              width: double.infinity,
              height: isSmallScreen ? 40 : 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors1.primaryGreen,
                    AppColors1.primaryGreen.withOpacity(0.8),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors1.glowGreen,
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 22),
                  onTap: () => _confirmSignOut(context),
                  child: Center(
                    child: Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors1.backgroundColor,
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: isSmallScreen ? 20 : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text, double fontSize) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors1.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 35, width: 1, color: AppColors1.borderGreen);
  }

  Widget _horizontalDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: AppColors1.borderGreen,
    );
  }

  Widget _settingsItemDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 30),
      color: AppColors1.borderGreen,
    );
  }

  Widget _badgeMockup(
    String label,
    String letter, {
    bool unlocked = false,
    required bool isSmallScreen,
  }) {
    final badgeSize = isSmallScreen ? 28.0 : 32.0;
    final letterSize = isSmallScreen ? 10.0 : 12.0;
    final labelSize = isSmallScreen ? 7.0 : 8.0;

    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color:
                    unlocked
                        ? AppColors1.primaryGreen
                        : AppColors1.iconBackgroundColor,
                borderRadius: BorderRadius.circular(badgeSize / 2),
                border: Border.all(
                  color:
                      unlocked
                          ? AppColors1.primaryGreen
                          : AppColors1.borderGreen,
                  width: 1,
                ),
                boxShadow:
                    unlocked
                        ? [
                          BoxShadow(
                            color: AppColors1.glowGreen,
                            blurRadius: 10,
                          ),
                        ]
                        : null,
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color:
                        unlocked
                            ? AppColors1.backgroundColor
                            : AppColors1.textTertiary,
                    fontSize: letterSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              label,
              style: TextStyle(
                color:
                    unlocked
                        ? AppColors1.primaryGreen
                        : AppColors1.textTertiary,
                fontSize: labelSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItemMockup(
    String label,
    String value, {
    bool hasStar = false,
    required Color color,
    required bool isSmallScreen,
    required double statValueSize,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: statValueSize,
                ),
              ),
              if (hasStar)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.star,
                    color: AppColors1.primaryGreen,
                    size: isSmallScreen ? 14 : 16,
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors1.textTertiary,
              fontSize: isSmallScreen ? 9 : 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _settingsItemMockup(
    String label,
    IconData icon, {
    VoidCallback? onTap,
    required bool isSmallScreen,
  }) {
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final textSize = isSmallScreen ? 13.0 : 14.0;
    final verticalPadding = isSmallScreen ? 10.0 : 12.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: verticalPadding,
          ),
          child: Row(
            children: [
              Container(
                width: iconSize + 10,
                height: iconSize + 10,
                decoration: BoxDecoration(
                  color: AppColors1.iconBackgroundColor,
                  borderRadius: BorderRadius.circular((iconSize + 10) / 2),
                ),
                child: Icon(
                  icon,
                  color: AppColors1.primaryGreen,
                  size: iconSize * 0.6,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10 : 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors1.textPrimary,
                    fontSize: textSize,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors1.textTertiary,
                size: textSize + 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
