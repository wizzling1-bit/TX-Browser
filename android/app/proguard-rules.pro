# Optimized ProGuard / R8 rules for Tx Browser

# Native application & bridge classes
-keep class com.wizzling.tx_browser.** { *; }

# Flutter Engine & Embedding (essential JNI & entry points)
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Play Core & Play Services
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**

# Flutter InAppWebView (Keep JavaScript interfaces & native callbacks)
-keep class com.pichillilorenzo.flutter_inappwebview_android.types.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview_android.chrome_custom_tabs.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview_android.in_app_browser.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview_android.webview.in_app_webview.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn com.pichillilorenzo.flutter_inappwebview_android.**

# SQLite3 and Drift Native Bindings
-keep class org.sqlite.** { *; }
-keep class com.simonbinder.sqlite3_flutter_libs.** { *; }
-dontwarn org.sqlite.**

# Google Mobile Ads (AdMob)
-keep public class com.google.android.gms.ads.** {
   public *;
}
-keep public class com.google.ads.** {
   public *;
}
-dontwarn com.google.android.gms.ads.**

# Google Play Services MLKit Barcode Scanning
-keep class com.google.mlkit.vision.barcode.** { *; }
-dontwarn com.google.mlkit.vision.barcode.**

# Android Biometrics and Local Auth
-keep class androidx.biometric.** { *; }

# Google Play Install Referrer
-keep class com.android.installreferrer.** { *; }
-dontwarn com.android.installreferrer.**

# AndroidX Core & Shortcuts
-keep class androidx.core.content.pm.** { *; }
-keep class androidx.core.graphics.drawable.IconCompat { *; }

# General warnings suppression
-dontwarn javax.annotation.**
-dontwarn java.awt.**
-dontwarn org.codehaus.mojo.animal_sniffer.**

# Firebase Messaging & Background Handler
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class io.flutter.plugins.firebase.messaging.** { *; }

# Flutter Local Notifications Plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Permission Handler Plugin
-keep class com.baseflow.permissionhandler.** { *; }

