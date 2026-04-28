// lib/config/environment.dart
abstract class Environment {
  static const String dev = 'dev';
  static const String staging = 'staging';
  static const String production = 'production';
}

class AppConfig {
  static String get firebaseWebApiKey {
    switch (_environment) {
      case Environment.dev:
        return 'AIzaSyDEV_KEY_HERE_123';
      case Environment.staging:
        return 'AIzaSySTAGING_KEY_HERE_456';
      case Environment.production:
        return 'AIzaSyPROD_KEY_HERE_789';
      default:
        return '';
    }
  }
  
  static String get dynamicLinkDomain {
    switch (_environment) {
      case Environment.dev:
        return 'https://devapp.page.link';
      case Environment.staging:
        return 'https://stagingapp.page.link';
      case Environment.production:
        return 'https://yourapp.page.link';
      default:
        return '';
    }
  }
  
  static String get baseUrl {
    switch (_environment) {
      case Environment.dev:
        return 'https://dev.yourapp.com';
      case Environment.staging:
        return 'https://staging.yourapp.com';
      case Environment.production:
        return 'https://yourapp.com';
      default:
        return '';
    }
  }
  
  static String get _environment {
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: Environment.dev);
    return environment;
  }
}