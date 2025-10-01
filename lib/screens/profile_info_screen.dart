import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'dart:ui';

class ProfileInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ProfileInfoScreen({super.key, required this.userData});

  @override
  _ProfileInfoScreenState createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    if (widget.userData != null) {
      final fullName = widget.userData?['name'] ?? '';
      if (fullName.isNotEmpty &&
          _firstNameController.text.isEmpty &&
          _lastNameController.text.isEmpty) {
        final nameParts = fullName.split(' ');
        _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
        _lastNameController.text =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }
      _phoneController.text = widget.userData?['phone'] ?? '';
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final fullName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        await _authService.updateUserProfile(
          name: fullName.trim(),
          phone: _phoneController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully'),
              backgroundColor: AppColors1.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to update profile: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _getInitials(String firstName, String lastName) {
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];
    return initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 410;

    // Responsive sizing
    final horizontalPadding =
        isSmallScreen ? 20.0 : (isMediumScreen ? 25.0 : 30.0);
    final headerFontSize =
        isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0);
    final avatarSize = isSmallScreen ? 80.0 : (isMediumScreen ? 90.0 : 100.0);
    final buttonHeight = isSmallScreen ? 45.0 : (isMediumScreen ? 48.0 : 50.0);
    final buttonFontSize =
        isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);

    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isSmallScreen ? 16 : 20,
              ),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: isSmallScreen ? 36 : 40,
                      height: isSmallScreen ? 36 : 40,
                      decoration: BoxDecoration(
                        color: AppColors1.iconBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors1.borderGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: AppColors1.primaryGreen,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 20),
                  Expanded(
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        color: AppColors1.textPrimary,
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Body - Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Avatar Card with gradient
                      Center(
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: AppColors1.deliveryCardGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(avatarSize / 2),
                            border: Border.all(
                              color: AppColors1.borderGreen,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors1.glowGreen,
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(avatarSize / 2),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                color: Colors.transparent,
                                child: Center(
                                  child: Text(
                                    _getInitials(
                                      _firstNameController.text,
                                      _lastNameController.text,
                                    ),
                                    style: TextStyle(
                                      color: AppColors1.primaryGreen,
                                      fontSize: isSmallScreen ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 24 : 40),

                      // Account Status Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors1.primaryGreen.withOpacity(0.1),
                              AppColors1.primaryGreen.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors1.borderGreen,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: isSmallScreen ? 36 : 40,
                                  height: isSmallScreen ? 36 : 40,
                                  decoration: BoxDecoration(
                                    color: AppColors1.iconBackgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    widget.userData?['verified'] == true
                                        ? Icons.verified
                                        : Icons.schedule,
                                    color: AppColors1.primaryGreen,
                                    size: isSmallScreen ? 18 : 20,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 12 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Account Status',
                                        style: TextStyle(
                                          color: AppColors1.textSecondary,
                                          fontSize: isSmallScreen ? 11 : 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.userData?['verified'] == true
                                            ? 'Verified Account'
                                            : 'Pending Verification',
                                        style: TextStyle(
                                          color: AppColors1.textPrimary,
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 10 : 12,
                                vertical: isSmallScreen ? 5 : 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors1.backgroundColor.withOpacity(
                                  0.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Member since ${_formatDate(widget.userData?['createdAt'])}',
                                style: TextStyle(
                                  color: AppColors1.textTertiary,
                                  fontSize: isSmallScreen ? 10 : 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 24 : 40),

                      // Form Fields
                      ..._buildFormFields(isSmallScreen),

                      // Error Message
                      if (_errorMessage.isNotEmpty) ...[
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: isSmallScreen ? 24 : 40),

                      // Save Button with Nible style
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
                            onTap: _isLoading ? null : _updateProfile,
                            child: Center(
                              child:
                                  _isLoading
                                      ? SizedBox(
                                        height: isSmallScreen ? 18 : 20,
                                        width: isSmallScreen ? 18 : 20,
                                        child: const CircularProgressIndicator(
                                          color: AppColors1.backgroundColor,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          color: AppColors1.backgroundColor,
                                          fontSize: buttonFontSize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 30 : 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields(bool isSmallScreen) {
    final labelSize = isSmallScreen ? 11.0 : 12.0;
    final fieldSpacing = isSmallScreen ? 16.0 : 20.0;

    return [
      // First Name Field
      _buildFieldLabel('First Name', labelSize),
      SizedBox(height: isSmallScreen ? 8 : 12),
      _buildInputField(
        controller: _firstNameController,
        hint: 'Enter your first name',
        icon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your first name';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {});
        },
        isSmallScreen: isSmallScreen,
      ),
      SizedBox(height: fieldSpacing),

      // Last Name Field
      _buildFieldLabel('Last Name', labelSize),
      SizedBox(height: isSmallScreen ? 8 : 12),
      _buildInputField(
        controller: _lastNameController,
        hint: 'Enter your last name',
        icon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your last name';
          }
          return null;
        },
        isSmallScreen: isSmallScreen,
      ),
      SizedBox(height: fieldSpacing),

      // Email Address Field (Read-only)
      _buildFieldLabel('Email Address', labelSize),
      SizedBox(height: isSmallScreen ? 8 : 12),
      _buildEmailField(isSmallScreen),
      SizedBox(height: fieldSpacing),

      // Phone Number Field
      _buildFieldLabel('Phone Number', labelSize),
      SizedBox(height: isSmallScreen ? 8 : 12),
      _buildInputField(
        controller: _phoneController,
        hint: 'Enter your phone number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your phone number';
          }
          return null;
        },
        isSmallScreen: isSmallScreen,
      ),
    ];
  }

  Widget _buildFieldLabel(String label, double fontSize) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors1.textSecondary,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Function(String)? onChanged,
    required bool isSmallScreen,
  }) {
    final fontSize = isSmallScreen ? 13.0 : 14.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final padding = isSmallScreen ? 12.0 : 14.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors1.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors1.borderGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: AppColors1.textPrimary, fontSize: fontSize),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors1.textTertiary.withOpacity(0.5),
            fontSize: fontSize,
          ),
          prefixIcon: Icon(
            icon,
            color: AppColors1.primaryGreen,
            size: iconSize,
          ),
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: padding,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          errorStyle: TextStyle(fontSize: isSmallScreen ? 10 : 11),
        ),
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _buildEmailField(bool isSmallScreen) {
    final fontSize = isSmallScreen ? 13.0 : 14.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final padding = isSmallScreen ? 12.0 : 14.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors1.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors1.borderGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            color: AppColors1.primaryGreen.withOpacity(0.5),
            size: iconSize,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              widget.userData?['email'] ?? 'user@example.com',
              style: TextStyle(
                color: AppColors1.textSecondary,
                fontSize: fontSize,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.lock_outline,
            color: AppColors1.textTertiary.withOpacity(0.5),
            size: iconSize - 2,
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'January 2024';

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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
