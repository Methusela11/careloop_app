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
      backgroundColor: const Color.fromARGB(255, 188, 192, 190),
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LOGO IMAGE
              Container(
                height: 80,
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo/careloop-t.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // HORIZONTAL SCROLLABLE CAROUSEL WITH IMAGES
              SizedBox(
                height: 240,
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
                          color: Colors.grey[100]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Image for each statement
                          Container(
                            height: 100,
                            width: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: AssetImage(item.imagePath),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Statement text
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
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

              // DOT INDICATORS (now updates with scroll)
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
                          ? const Color.fromARGB(255, 230, 101, 15)
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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.fromARGB(255, 230, 101, 15),
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Model for carousel items with images
class CarouselItem {
  final String title;
  final String subtitle;
  final String imagePath;

  CarouselItem({
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

// List of carousel items with different statements and images
final List<CarouselItem> carouselItems = [
  CarouselItem(
    title: "Stay Connected",
    subtitle: "Keep in touch with your loved ones in real-time",
    imagePath: 'assets/images/connected.png',
  ),
  CarouselItem(
    title: "Stay Safe",
    subtitle: "Emergency alerts and location sharing for peace of mind",
    imagePath: 'assets/images/safe.png',
  ),
  CarouselItem(
    title: "24/7 Support",
    subtitle: "Round-the-clock assistance whenever you need it",
    imagePath: 'assets/images/support.png',
  ),
];
