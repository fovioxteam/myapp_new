import 'package:get/get.dart';

abstract class ProfileBaseController extends GetxController {
  // User data
  final RxString username = ''.obs;
  final RxString bio = ''.obs;
  final RxString avatarUrl = ''.obs;
  
  // Counters
  final RxInt followersCount = 0.obs;
  final RxInt followingCount = 0.obs;
  final RxInt postsCount = 0.obs;
  
  // Posts
  final RxList<Map<String, dynamic>> userPosts = <Map<String, dynamic>>[].obs;
  
  // Loading state
  final RxBool isLoading = false.obs;
  
  // Abstract methods
  Future<void> loadUserData(String userId);
  
  @override
  void onClose() {
    // Clean up resources
    super.onClose();
  }
}