// lib/screens/welcome_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/auth_controller.dart';
import 'policy_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;

  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(_logoFade);

    _buttonsFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_buttonsFade);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Проверяем, можем ли вернуться назад (если это модальное окно)
    final bool isModal = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // 🔥 СТРЕЛОЧКА НАЗАД (только если это модальное окно)
            if (isModal)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  padding: const EdgeInsets.all(8),
                  splashRadius: 24,
                ),
              ),
            
            // Основной контент
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// 🔥 LOGO ANIMATION
                    FadeTransition(
                      opacity: _logoFade,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: Text(
                          'Foviox',
                          style: GoogleFonts.pacifico(
                            fontSize: 38,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    /// 🔥 BUTTONS ANIMATION
                    FadeTransition(
                      opacity: _buttonsFade,
                      child: SlideTransition(
                        position: _buttonsSlide,
                        child: Column(
                          children: [
                            // Google
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Obx(() => OutlinedButton.icon(
                                    onPressed: authController.isLoading.value
                                        ? null
                                        : () async {
                                            await authController.loginWithGoogle();
                                            if (authController.isLoggedIn) {
                                              if (Navigator.canPop(context)) {
                                                Navigator.pop(context, true);
                                              }
                                            }
                                          },
                                    icon: Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'G',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Roboto',
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    label: authController.isLoading.value
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Continue with Google',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  )),
                            ),

                            const SizedBox(height: 16),

                            // Apple
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (kIsWeb) {
                                    Get.snackbar(
                                      'Apple Sign In',
                                      'Apple login not supported on web yet',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: Colors.grey.shade100,
                                      colorText: Colors.black,
                                    );
                                  } else {
                                    authController.loginWithApple();
                                  }
                                },
                                icon: Icon(
                                  Icons.apple,
                                  size: 22,
                                  color:
                                      isDark ? Colors.white : Colors.black,
                                ),
                                label: Text(
                                  'Continue with Apple',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Terms
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  'By continuing, you agree to our',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(() =>
                                      const PolicyScreen(showPrivacy: false)),
                                  child: Text(
                                    'Terms',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                Text(
                                  'and',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Get.to(() =>
                                      const PolicyScreen(showPrivacy: true)),
                                  child: Text(
                                    'Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}