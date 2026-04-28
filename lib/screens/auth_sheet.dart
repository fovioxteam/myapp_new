import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class AuthSheet extends StatelessWidget {
  const AuthSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Sign in to Foviox',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 24),

          // GOOGLE
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Obx(() => OutlinedButton(
                  onPressed: auth.isLoading.value
                      ? null
                      : () => auth.loginWithGoogle(),
                  child: auth.isLoading.value
                      ? const CircularProgressIndicator()
                      : const Text('Continue with Google'),
                )),
          ),

          const SizedBox(height: 12),

          // APPLE
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () => auth.loginWithApple(),
              child: const Text('Continue with Apple'),
            ),
          ),
        ],
      ),
    );
  }
}