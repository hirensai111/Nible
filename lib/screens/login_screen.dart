import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _needsEmailVerification = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _needsEmailVerification = false;
      });
      try {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null && !user.emailVerified) {
          setState(() {
            _needsEmailVerification = true;
          });
          await user.sendEmailVerification();
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isFirstLogin', true);

        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No user found with this email.';
            break;
          case 'wrong-password':
            errorMessage = 'Incorrect password.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
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
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      User? user = userCredential.user;
      if (user != null) {
        await Future.delayed(const Duration(seconds: 2));
        await user.reload();
        if (user.emailVerified) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isFirstLogin', true);
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          setState(() {
            _errorMessage =
                'Email not yet verified. Please check your inbox or resend the verification email.';
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: ${e.message}. Please try again.';
      });
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
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      User? user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email resent. Check your inbox.'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      } else if (user != null && user.emailVerified) {
        setState(() {
          _errorMessage =
              'Email is already verified. Please proceed to sign in.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend email: ${e.message}';
      });
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
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF00FF88),
            Color(0xFF00D9FF),
          ],
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
          style: TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: onToggleVisibility != null
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
        gradient: isPrimary
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF00FF88),
                  Color(0xFF00CC6A),
                ],
              )
            : LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF2A2A2A),
                  Color(0xFF1A1A1A),
                ],
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
        child: isLoading
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
                  SizedBox(height: isSmallScreen ? 30 : 60),

                  // Logo Section
                  Column(
                    children: [
                      Container(
                        width: isSmallScreen ? 80 : (isMediumScreen ? 100 : 120),
                        height: isSmallScreen ? 80 : (isMediumScreen ? 100 : 120),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00FF88),
                              Color(0xFF00D9FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 30),
                        ),
                        child: Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 40 : (isMediumScreen ? 50 : 60),
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 20),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Color(0xFF00FF88),
                            Color(0xFF00D9FF),
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'Nible',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 28 : (isMediumScreen ? 34 : 40),
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isSmallScreen ? 24 : 40),

                  // Login Form
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 24),
                      border: Border.all(
                        color: Color(0xFF00FF88).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: !_needsEmailVerification
                          ? [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Color(0xFF00FF88),
                                    Color(0xFF00D9FF),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'Welcome Back!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 22 : 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Color(0xFF00FF88),
                                    Color(0xFF00D9FF),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'Sign in with your VT credentials',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 16 : 24),

                              _buildTextField(
                                label: 'VT Email',
                                hint: 'Enter your VT email address',
                                controller: _emailController,
                                obscureText: false,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isSmallScreen ? 12 : 16),

                              _buildTextField(
                                label: 'Password',
                                hint: 'Enter your password',
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onToggleVisibility: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  return null;
                                },
                              ),

                              SizedBox(height: isSmallScreen ? 8 : 16),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: Handle forgot password
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 12 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              if (_errorMessage.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.only(top: 8),
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
                              Column(
                                children: [
                                  Container(
                                    width: isSmallScreen ? 60 : 80,
                                    height: isSmallScreen ? 60 : 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
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
                                    onPressed: _isLoading ? null : _checkEmailVerification,
                                    isLoading: _isLoading,
                                  ),

                                  SizedBox(height: isSmallScreen ? 8 : 12),

                                  _buildGreenButton(
                                    text: 'Resend Email',
                                    onPressed: _isLoading ? null : _resendVerificationEmail,
                                    isLoading: false,
                                    isPrimary: false,
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
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                    ),
                  ),

                  if (!_needsEmailVerification) ...[
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    _buildGreenButton(
                      text: 'Sign In',
                      onPressed: _isLoading ? null : _signIn,
                      isLoading: _isLoading,
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 32),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Color(0xFF00FF88).withOpacity(0.5),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFF00FF88).withOpacity(0.5),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 32),

                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 4 : 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: Text(
                              'Create Account',
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

                    SizedBox(height: isSmallScreen ? 16 : 24),

                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'By signing in, you agree to our Terms of Service and FERPA Consent Agreement',
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}