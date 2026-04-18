import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // Auto-scroll every 6 seconds
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % carouselItems.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 1, 133, 29),
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 246, 139, 0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 246, 139, 0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -50,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 246, 139, 0).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Center content with downward positioning
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(), // Pushes content down
                Container(
                  width: 330,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // LOGO IMAGE
                      Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 253, 253, 253)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/logo/careloop-t.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.health_and_safety,
                                size: 40,
                                color: const Color.fromARGB(255, 10, 6, 0),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // App Title
                      Text(
                        "CareLoop",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 1, 133, 29),
                          letterSpacing: 1.2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        "Stay Connected. Stay Safe.",
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color.fromARGB(255, 246, 139, 0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // HORIZONTAL SCROLLABLE CAROUSEL WITH IMAGES
                      SizedBox(
                        height: 230,
                        child: PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.horizontal,
                          itemCount: carouselItems.length,
                          physics: const BouncingScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = carouselItems[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Image for each statement with error handling
                                  Container(
                                    height: 80,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color:
                                          const Color.fromARGB(255, 255, 255, 255)
                                              .withOpacity(0.1),
                                    ),
                                    child: Image.asset(
                                      item.imagePath,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          item.icon,
                                          size: 35,
                                          color: const Color.fromARGB(255, 8, 5, 0),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Statement text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      item.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      item.subtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // DOT INDICATORS (updates with scroll)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          carouselItems.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentPage == index
                                  ? const Color.fromARGB(255, 246, 139, 0)
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BUTTON (arrow)
                      GestureDetector(
                        onTap: () {
                          _timer.cancel(); // Stop timer when navigating
                          Navigator.pushReplacementNamed(context, "/login");
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color.fromARGB(255, 246, 139, 0),
                                const Color.fromARGB(255, 246, 111, 0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(255, 246, 98, 0)
                                    .withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40), // Space at bottom
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Model for carousel items with images and fallback icons
class CarouselItem {
  final String title;
  final String subtitle;
  final String imagePath;
  final IconData icon; // Fallback icon in case image fails to load

  CarouselItem({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.icon,
  });
}

// List of carousel items with different statements and images
final List<CarouselItem> carouselItems = [
  CarouselItem(
    title: "Stay Connected",
    subtitle: "Keep in touch with your loved ones in real-time",
    imagePath: 'assets/images/connected.png',
    icon: Icons.connected_tv,
  ),
  CarouselItem(
    title: "Stay Safe",
    subtitle: "Emergency alerts and location sharing for peace of mind",
    imagePath: 'assets/images/safe.png',
    icon: Icons.security,
  ),
  CarouselItem(
    title: "24/7 Support",
    subtitle: "Round-the-clock assistance whenever you need it",
    imagePath: 'assets/images/support.png',
    icon: Icons.support_agent,
  ),
];
