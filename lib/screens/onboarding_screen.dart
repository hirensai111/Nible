import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'signup_screen.dart'; // Import SignupScreen

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Order From Anywhere',
      description: 'Get your favorite dining hall food delivered to your dorm, library, or anywhere on campus.',
      icon: Icons.location_on_outlined,
    ),
    OnboardingPage(
      title: 'Quick & Reliable',
      description: 'Student delivery partners ensure your food arrives fresh and on time.',
      icon: Icons.directions_bike_outlined,
    ),
    OnboardingPage(
      title: 'Help Fellow Hokies',
      description: 'Support other students while enjoying convenient service from people you can trust.',
      icon: Icons.people_outline,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return OnboardingPageWidget(
                    page: _pages[index],
                    theme: theme,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                            ? AppColors.hokieOrange 
                            : theme.colorScheme.onBackground.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Navigate to the signup screen
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.hokieMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1 ? 'Continue' : 'Get Started',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () {
                        // Navigate to the signup screen
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingPageWidget extends StatelessWidget {
  final OnboardingPage page;
  final ThemeData theme;

  const OnboardingPageWidget({
    super.key,
    required this.page,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 160,
            width: 160,
            decoration: BoxDecoration(
              color: AppColors.hokieMaroon.withOpacity(0.2),
              borderRadius: BorderRadius.circular(80),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: AppColors.hokieOrange,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.hokieOrange,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onBackground,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}