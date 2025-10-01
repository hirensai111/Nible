import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nible/screens/login_screen.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isVerificationSent = false;
  bool _isVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Combine first and last name
        String fullName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

        await _authService.createUserWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
          fullName,
        );

        User? user = FirebaseAuth.instance.currentUser;

        // ✅ FIX: Create Firestore user document using UID
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name':
                fullName, // Full name as single field (matches existing structure)
            'email': _emailController.text.trim(),
            'credits': 0.0,
            'earnings': 0.0,
            'transactions': [],
            'createdAt': FieldValue.serverTimestamp(),
          });

          if (!user.emailVerified) {
            await user.sendEmailVerification();
            setState(() {
              _isVerificationSent = true;
            });
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already in use.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          case 'weak-password':
            errorMessage = 'The password is too weak.';
            break;
          default:
            errorMessage = 'An error occurred: ${e.message}';
        }
        setState(() {
          _errorMessage = errorMessage;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
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

  Future<void> _checkEmailVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          setState(() {
            _isVerified = true;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email verified successfully'),
              backgroundColor: Color(0xFF00FF88),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          setState(() {
            _errorMessage =
                'Email not yet verified. Please check your inbox or resend the verification email.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking verification: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email resent. Check your inbox.'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend email: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscureText,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF00FF88), Color(0xFF00D9FF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon:
                onToggleVisibility != null
                    ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Color(0xFF00FF88),
                      ),
                      onPressed: onToggleVisibility,
                    )
                    : null,
          ),
          validator: validator,
        ),
      ),
    );
  }

  Widget _buildGreenButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isLoading,
    bool isPrimary = true,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient:
            isPrimary
                ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
                )
                : LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            isLoading
                ? CircularProgressIndicator(
                  color: isPrimary ? Colors.black : Color(0xFF00FF88),
                  strokeWidth: 2,
                )
                : Text(
                  text,
                  style: TextStyle(
                    color: isPrimary ? Colors.black : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isMediumScreen = screenHeight >= 700 && screenHeight < 850;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 400 ? 16.0 : 24.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isSmallScreen ? 20 : 40),

                  // Logo Section
                  Column(
                    children: [
                      Container(
                        width: isSmallScreen ? 70 : (isMediumScreen ? 85 : 100),
                        height:
                            isSmallScreen ? 70 : (isMediumScreen ? 85 : 100),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF00FF88), Color(0xFF00D9FF)],
                          ),
                          borderRadius: BorderRadius.circular(
                            isSmallScreen ? 18 : 25,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              fontSize:
                                  isSmallScreen
                                      ? 35
                                      : (isMediumScreen ? 42 : 50),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 16),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => LinearGradient(
                              colors: [Color(0xFF00FF88), Color(0xFF00D9FF)],
                            ).createShader(bounds),
                        child: Text(
                          'Nible',
                          style: TextStyle(
                            fontSize:
                                isSmallScreen ? 24 : (isMediumScreen ? 28 : 32),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmallScreen ? 24 : 32),

                  // Signup Form
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(
                        isSmallScreen ? 16 : 20,
                      ),
                      border: Border.all(
                        color: Color(0xFF00FF88).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          !_isVerificationSent
                              ? [
                                // Title
                                ShaderMask(
                                  shaderCallback:
                                      (bounds) => LinearGradient(
                                        colors: [
                                          Color(0xFF00FF88),
                                          Color(0xFF00D9FF),
                                        ],
                                      ).createShader(bounds),
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 20 : 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 4 : 8),
                                ShaderMask(
                                  shaderCallback:
                                      (bounds) => LinearGradient(
                                        colors: [
                                          Color(0xFF00FF88),
                                          Color(0xFF00D9FF),
                                        ],
                                      ).createShader(bounds),
                                  child: Text(
                                    'Join the VT delivery community',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 16 : 24),

                                // First Name
                                _buildTextField(
                                  label: 'First Name',
                                  hint: 'Enter your first name',
                                  controller: _firstNameController,
                                  obscureText: false,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your first name';
                                    }
                                    return null;
                                  },
                                ),

                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Last Name
                                _buildTextField(
                                  label: 'Last Name',
                                  hint: 'Enter your last name',
                                  controller: _lastNameController,
                                  obscureText: false,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your last name';
                                    }
                                    return null;
                                  },
                                ),

                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Email
                                _buildTextField(
                                  label: 'VT Email',
                                  hint: 'Enter your VT email address',
                                  controller: _emailController,
                                  obscureText: false,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    if (!value.endsWith('@vt.edu')) {
                                      return 'Please use a VT email (e.g., @vt.edu)';
                                    }
                                    return null;
                                  },
                                ),

                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Password
                                _buildTextField(
                                  label: 'Password',
                                  hint: 'Create a secure password',
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                SizedBox(height: isSmallScreen ? 12 : 16),

                                // Confirm Password
                                _buildTextField(
                                  label: 'Confirm Password',
                                  hint: 'Re-enter your password',
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  onToggleVisibility: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),

                                if (_errorMessage.isNotEmpty)
                                  Container(
                                    margin: EdgeInsets.only(top: 16),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 12 : 14,
                                      ),
                                    ),
                                  ),
                              ]
                              : [
                                // Email Verification UI
                                Column(
                                  children: [
                                    Container(
                                      width: isSmallScreen ? 60 : 80,
                                      height: isSmallScreen ? 60 : 80,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(
                                          isSmallScreen ? 15 : 20,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.mark_email_read_outlined,
                                        size: isSmallScreen ? 30 : 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 16 : 20),
                                    Text(
                                      'Check Your Email',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 20 : 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: isSmallScreen ? 8 : 12),
                                    Text(
                                      'We sent a verification link to\n${_emailController.text}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: isSmallScreen ? 14 : 16,
                                      ),
                                    ),
                                    SizedBox(height: isSmallScreen ? 16 : 24),

                                    _buildGreenButton(
                                      text: 'I Have Verified',
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _checkEmailVerification,
                                      isLoading: _isLoading,
                                    ),

                                    SizedBox(height: isSmallScreen ? 8 : 12),

                                    _buildGreenButton(
                                      text: 'Resend Email',
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _resendVerificationEmail,
                                      isLoading: false,
                                      isPrimary: false,
                                    ),

                                    if (_errorMessage.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(top: 16),
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Text(
                                          _errorMessage,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                    ),
                  ),

                  if (!_isVerificationSent) ...[
                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Create Account Button
                    _buildGreenButton(
                      text: 'Create Account',
                      onPressed: _isLoading ? null : _createAccount,
                      isLoading: _isLoading,
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Already have account section
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF00FF88),
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 8 : 16),

                    // Terms and conditions
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'By signing up, you agree to our Terms of Service and FERPA Consent Agreement',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isSmallScreen ? 10 : 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: isSmallScreen ? 20 : 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
