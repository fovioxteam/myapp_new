import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityController extends GetxController {
  final RxBool hasInternet = true.obs;
  final Connectivity _connectivity = Connectivity();
  
  @override
  void onInit() {
    super.onInit();
    checkConnectivity();
    
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }
  
  Future<void> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('❌ Connectivity check error: $e');
    }
  }
  
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      hasInternet.value = false;
    } else {
      hasInternet.value = true;
    }
    
    print('📡 Internet connection: ${hasInternet.value}');
  }
}