import 'package:flutter/material.dart';
import 'package:nible/screens/order_screen.dart';
import 'package:nible/screens/wallet_screen.dart';
import '../constants/colors.dart';
import '../widgets/chat_bubble.dart';
import 'home_content.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const OrdersScreen(),
    const ProfileScreen(),
    const WalletScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure black background
      body: Stack(
        children: [
          // Current screen based on tab index
          _screens[_currentIndex],

          // Floating chat bubble
          const Positioned(
            bottom: 80, // Position above the bottom navigation bar
            right: 16,
            child: FloatingChatBubble(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF050505), // Darker than 0A0A0A for nav bar
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF00FF88), // Nible green
          unselectedItemColor: Colors.white.withOpacity(0.5),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.home_outlined, 0),
              activeIcon: _buildNavIcon(Icons.home, 0, isActive: true),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.receipt_long_outlined, 1),
              activeIcon: _buildNavIcon(Icons.receipt_long, 1, isActive: true),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.person_outline, 2),
              activeIcon: _buildNavIcon(Icons.person, 2, isActive: true),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: _buildNavIcon(Icons.account_balance_wallet_outlined, 3),
              activeIcon: _buildNavIcon(Icons.account_balance_wallet, 3, isActive: true),
              label: 'Wallet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool isActive = false}) {
    final bool isSelected = _currentIndex == index;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected && isActive 
            ? const Color(0xFF00FF88).withOpacity(0.15)
            : Colors.transparent,
      ),
      child: Icon(
        icon,
        size: 24,
        color: isSelected && isActive
            ? const Color(0xFF00FF88)
            : Colors.white.withOpacity(0.5),
      ),
    );
  }
}