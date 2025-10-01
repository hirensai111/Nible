import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nible/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'constants/colors.dart';
import 'screens/delivery_mode_screen.dart';
import 'firebase_options.dart';

// Navigator key for global routing (used in notifications)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool _isAppInitialized = false;
RemoteMessage? _pendingMessage;
StreamSubscription<String>? _tokenRefreshSubscription;
StreamSubscription<User?>? _authStateSubscription;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🔔 Background message: ${message.messageId}');
    print('📱 Background message data: ${message.data}');
  } catch (e) {
    print('❌ Background handler error: $e');
  }
}

Future<void> saveFcmTokenToFirestore() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in, skipping FCM token save');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': token},
      );
      print("✅ FCM Token saved: $token");
    } else {
      print("⚠️ No FCM token received");
    }
  } catch (e) {
    print("❌ Error saving FCM token: $e");
    // Don't throw - just log and continue
  }
}

void setupFcmTokenRefresh() {
  // Cancel any existing subscription first
  _tokenRefreshSubscription?.cancel();

  _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
    (newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': newToken});
          print('🔄 FCM token refreshed: $newToken');
        } catch (e) {
          print("❌ Error refreshing FCM token: $e");
        }
      } else {
        print('⚠️ Token refresh attempted but no user logged in');
      }
    },
    onError: (error) {
      print('❌ FCM token refresh error: $error');
    },
  );
}

void cancelFcmTokenRefresh() {
  _tokenRefreshSubscription?.cancel();
  _tokenRefreshSubscription = null;
  print('🛑 FCM token refresh listener canceled');
}

void handleNotificationClick(Map<String, dynamic> data) {
  print('🔔 Handling notification click: $data');

  if (data['type'] == 'new_message' &&
      data['conversationId'] != null &&
      data['otherUserId'] != null) {
    final conversationId = data['conversationId'];
    final otherUserId = data['otherUserId'];

    if (!_isAppInitialized) {
      _pendingMessage = RemoteMessage(data: data);
      return;
    }

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (navigatorKey.currentState == null) {
        print('❌ Navigator not available');
        return;
      }

      try {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder:
                (_) => ChatScreen(
                  conversationId: conversationId,
                  otherUserId: otherUserId,
                ),
          ),
        );
        print('✅ Navigated to chat');
      } catch (e) {
        print('❌ Navigation error: $e');
      }
    });
  }
}

void processPendingNotifications() {
  _isAppInitialized = true;

  if (_pendingMessage != null) {
    print('⏱️ Processing pending message: ${_pendingMessage!.data}');
    handleNotificationClick(_pendingMessage!.data);
    _pendingMessage = null;
  }
}

Future<void> setupNotifications() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('📱 Notification permission: ${settings.authorizationStatus}');

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('📱 Initial message found: ${initialMessage.data}');
      _pendingMessage = initialMessage;
    }

    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        print('📱 App opened from background via message: ${message.data}');
        handleNotificationClick(message.data);
      },
      onError: (error) {
        print('❌ onMessageOpenedApp error: $error');
      },
    );

    FirebaseMessaging.onMessage.listen(
      (message) {
        print('📩 Foreground message: ${message.notification?.title}');
        print('📩 Foreground data: ${message.data}');
      },
      onError: (error) {
        print('❌ onMessage error: $error');
      },
    );

    print('✅ Notifications setup complete');
  } catch (e) {
    print('❌ Notification setup error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Handle Firebase initialization with duplicate app check
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        print('ℹ️ Firebase already initialized, continuing...');
        // Firebase is already initialized, which is fine
      } else {
        print('❌ Firebase initialization error: $e');
        rethrow;
      }
    }

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize Stripe
    Stripe.publishableKey =
        'pk_test_51RLXhpPMww4AvxzXhlLYmZwYoT8uh57eeXLX1jGXWF8GRMGx1cJSmhyINfmZTGTh90ExNQumQu8DNMXuIfsztxkL00OuZJTjwl';

    print('✅ Stripe initialized successfully');
  } catch (e, stackTrace) {
    print('❌ Main initialization error: $e');
    print('Stack trace: $stackTrace');
    // Continue to run the app even if there are initialization errors
  }

  // Run the app outside of any zone guards
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late Future<Widget> _initialScreenFuture;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialScreenFuture = _getInitialScreen();
    _setupAuthStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cancelFcmTokenRefresh();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('📱 App lifecycle state: $state');

    // Handle app lifecycle for better state management
    if (state == AppLifecycleState.resumed && _isInitialized) {
      if (kDebugMode) {
        print('🔄 App resumed - checking auth state');
      }
    }
  }

  void _setupAuthStateListener() {
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        print('🔐 Auth state changed: ${user?.uid ?? 'null'}');

        if (user == null) {
          // User signed out - clean up
          cancelFcmTokenRefresh();
          _pendingMessage = null;
          _isAppInitialized = false;
        } else {
          // User signed in - set up notifications if not already done
          if (_isInitialized) {
            setupNotifications();
            saveFcmTokenToFirestore();
            setupFcmTokenRefresh();
          }
        }
      },
      onError: (error) {
        print('❌ Auth state error: $error');
      },
    );
  }

  Future<Widget> _getInitialScreen() async {
    try {
      // Add a small delay in debug mode for stability
      if (kDebugMode) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final prefs = await SharedPreferences.getInstance();
      final isFirstLogin = prefs.getBool('isFirstLogin') ?? false;
      final user = FirebaseAuth.instance.currentUser;

      print('📱 Initial screen check:');
      print('  - User: ${user?.uid ?? 'null'}');
      print('  - First login: $isFirstLogin');

      if (user != null) {
        // User is logged in - set up notifications
        try {
          await setupNotifications();
          await saveFcmTokenToFirestore();
          setupFcmTokenRefresh();
          print('✅ User notifications configured');
        } catch (e) {
          print('⚠️ Notification setup failed (non-fatal): $e');
        }
      } else {
        print('ℹ️ No user logged in, skipping notification setup');
      }

      _isInitialized = true;

      // Navigate based on login status
      if (!isFirstLogin || user == null) {
        return const SplashScreen();
      } else {
        return const MainScreen();
      }
    } catch (e, stackTrace) {
      print('❌ Initial screen error: $e');
      print('Stack trace: $stackTrace');
      // Always return something, even on error
      return const SplashScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nible',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        // Primary colors
        primaryColor: AppColors1.primaryGreen,
        scaffoldBackgroundColor: AppColors1.backgroundColor,

        // Color scheme
        colorScheme: ColorScheme.dark(
          primary: AppColors1.primaryGreen,
          secondary: AppColors1.primaryGreen,
          background: AppColors1.backgroundColor,
          surface: AppColors1.surfaceColor,
          error: Colors.red,
          onPrimary: AppColors1.backgroundColor,
          onSecondary: AppColors1.backgroundColor,
          onBackground: AppColors1.textPrimary,
          onSurface: AppColors1.textPrimary,
        ),

        // AppBar theme
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors1.backgroundColor,
          foregroundColor: AppColors1.textPrimary,
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: AppColors1.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Card theme
        cardTheme: CardTheme(
          color: AppColors1.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors1.borderGreen, width: 1),
          ),
        ),

        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors1.primaryGreen,
            foregroundColor: AppColors1.backgroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),

        // Text button theme
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors1.primaryGreen),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors1.iconBackgroundColor.withOpacity(0.5),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors1.iconBackgroundColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors1.primaryGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          labelStyle: TextStyle(color: AppColors1.textTertiary),
          hintStyle: TextStyle(color: AppColors1.textSubtle),
        ),

        // Dialog theme
        dialogTheme: DialogTheme(
          backgroundColor: AppColors1.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: const TextStyle(
            color: AppColors1.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(
            color: AppColors1.textSecondary,
            fontSize: 16,
          ),
        ),

        // Text theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors1.textPrimary),
          displayMedium: TextStyle(color: AppColors1.textPrimary),
          displaySmall: TextStyle(color: AppColors1.textPrimary),
          headlineLarge: TextStyle(color: AppColors1.textPrimary),
          headlineMedium: TextStyle(color: AppColors1.textPrimary),
          headlineSmall: TextStyle(color: AppColors1.textPrimary),
          titleLarge: TextStyle(color: AppColors1.textPrimary),
          titleMedium: TextStyle(color: AppColors1.textPrimary),
          titleSmall: TextStyle(color: AppColors1.textPrimary),
          bodyLarge: TextStyle(color: AppColors1.textPrimary),
          bodyMedium: TextStyle(color: AppColors1.textPrimary),
          bodySmall: TextStyle(color: AppColors1.textPrimary),
          labelLarge: TextStyle(color: AppColors1.textPrimary),
          labelMedium: TextStyle(color: AppColors1.textPrimary),
          labelSmall: TextStyle(color: AppColors1.textPrimary),
        ),

        // Progress indicator theme
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors1.primaryGreen,
        ),

        // Bottom navigation bar theme
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors1.navBarColor,
          selectedItemColor: AppColors1.primaryGreen,
          unselectedItemColor: AppColors1.textSecondary,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const MainScreen(),
        '/delivery-mode': (context) => const DeliveryModeScreen(),
      },
      home: FutureBuilder<Widget>(
        future: _initialScreenFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              print('❌ FutureBuilder error: ${snapshot.error}');
              return const SplashScreen();
            }

            if (snapshot.hasData) {
              // Schedule processing of pending notifications
              WidgetsBinding.instance.addPostFrameCallback((_) {
                processPendingNotifications();
              });
              return snapshot.data!;
            }
          }

          // Show loading screen with Nible theme
          return Scaffold(
            backgroundColor: AppColors1.backgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors1.primaryGreen,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nible',
                    style: TextStyle(
                      color: AppColors1.primaryGreen,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kDebugMode
                        ? 'Initializing (Debug Mode)...'
                        : 'Initializing...',
                    style: TextStyle(
                      color: AppColors1.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Debug builds may take longer',
                      style: TextStyle(
                        color: AppColors1.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
