# Flutter Engine Play Store Deferred Components
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# General Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Media & Firebase
-dontwarn com.google.firebase.**
-dontwarn androidx.**