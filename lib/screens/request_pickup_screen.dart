import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/colors.dart';
import 'request_confirmation_screen.dart';
import 'package:flutter/services.dart';
import '../services/order_service.dart'; // Add this import

class RequestPickupScreen extends StatefulWidget {
  const RequestPickupScreen({super.key});

  @override
  State<RequestPickupScreen> createState() => _RequestPickupScreenState();
}

class _RequestPickupScreenState extends State<RequestPickupScreen>
    with SingleTickerProviderStateMixin {
  String selectedDiningHall = 'Dietrick Hall';
  final TextEditingController deliveryLocationController =
      TextEditingController();
  double totalFee = 3.00;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> diningHalls = [
    'Dietrick Hall',
    'Owens Food Court',
    'Perry Place',
    'Turners Place',
    'Owens HG',
    'West End',
  ];

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
    _ensureAuthentication();
    _loadUserAndSetFee();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadUserAndSetFee() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      final tier = data?['subscriptionTier'] ?? 'free';

      setState(() {
        if (tier == 'delivery_plus' || tier == 'all_access') {
          totalFee = 2.50;
        } else {
          totalFee = 3.00;
        }
      });
    } catch (e) {
      print('Error loading subscription tier: $e');
    }
  }

  @override
  void dispose() {
    deliveryLocationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _ensureAuthentication() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        await _auth.signInAnonymously();
      }
    } catch (e) {
      print("Auth error: $e");
    }
  }

  Future<void> _submitRequest() async {
    if (deliveryLocationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors1.cardColor,
          content: Text(
            'Please enter a delivery location',
            style: TextStyle(color: AppColors1.textPrimary),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    _animationController.forward().then((_) => _animationController.reverse());

    try {
      // Use the OrderService to create the order
      final orderService = OrderService();
      final orderResult = await orderService.createPickupOrder(
        diningHall: selectedDiningHall,
        deliveryLocation: deliveryLocationController.text,
        totalFee: totalFee,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => RequestConfirmationScreen(
                  requestId: orderResult.orderId, // Now using the sequential ID
                  diningHall: orderResult.diningHall,
                  deliveryLocation: orderResult.deliveryLocation,
                  totalFee: orderResult.totalFee,
                  orderReference: orderResult.orderId, // Same as requestId now
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors1.cardColor,
            content: Text(
              'Error: ${e.toString()}',
              style: TextStyle(color: AppColors1.textPrimary),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors1.surfaceColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Request Pickup',
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dining Hall Image Tile
                    _buildDiningHallImageTile(),
                    const SizedBox(height: 30),

                    _buildSectionTitle('Dining Hall'),
                    const SizedBox(height: 12),
                    _buildDiningHallInput(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Order Confirmation'),
                    const SizedBox(height: 12),
                    _buildImageSelector(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Delivery Location'),
                    const SizedBox(height: 12),
                    _buildLocationInput(),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Delivery Fee'),
                    const SizedBox(height: 12),
                    _buildFeeDetails(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            // Submit Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildSubmitButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiningHallImageTile() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors1.borderGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder or actual image
            _buildDiningHallImage(),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            // Dining hall name overlay
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedDiningHall,
                    style: TextStyle(
                      color: AppColors1.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dining Halls',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiningHallImage() {
    // Check if we have an image path for this dining hall
    final imagePath = diningHallImages[selectedDiningHall];

    if (imagePath != null) {
      // Try to load the actual image
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If image fails to load, show placeholder
          return _buildImagePlaceholder();
        },
      );
    } else {
      // No image path defined, show placeholder
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors1.iconBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, color: AppColors1.textSubtle, size: 48),
            const SizedBox(height: 8),
            Text(
              'Dining Hall',
              style: TextStyle(color: AppColors1.textSubtle, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors1.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildDiningHallInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedDiningHall,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              selectedDiningHall = newValue;
            });
          }
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        dropdownColor: AppColors1.cardColor,
        style: TextStyle(color: AppColors1.textPrimary, fontSize: 16),
        icon: Icon(Icons.arrow_drop_down, color: AppColors1.textPrimary),
        items:
            diningHalls.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(color: AppColors1.textPrimary),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: _showImagePickerDialog,
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors1.iconBackgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, color: AppColors1.textPrimary, size: 28),
            const SizedBox(height: 6),
            Text(
              'Tap to take a screenshot',
              style: TextStyle(color: AppColors1.textSubtle, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: deliveryLocationController,
        inputFormatters: [UpperCaseTextFormatter()],
        style: TextStyle(color: AppColors1.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Enter delivery location',
          hintStyle: TextStyle(color: AppColors1.textSubtle, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFeeDetails() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Delivery Fee',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '\$${totalFee.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors1.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors1.primaryGreen,
              borderRadius: BorderRadius.circular(24),
              boxShadow:
                  _isSubmitting
                      ? []
                      : [
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
                borderRadius: BorderRadius.circular(24),
                onTap: _isSubmitting ? null : _submitRequest,
                child: Center(
                  child:
                      _isSubmitting
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Request',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImagePickerDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors1.cardColor,
        content: Text(
          'Image upload feature coming soon!',
          style: TextStyle(color: AppColors1.textPrimary),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
