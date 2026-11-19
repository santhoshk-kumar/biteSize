# BiteSize ProGuard / R8 Optimization & Shrinking Rules

# Flutter Wrapper & Platform Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Desugar JDK Libraries (java.time & streams backport)
-dontwarn java.time.**
-dontwarn java.lang.invoke.**

# Flutter Local Notifications Plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# SQLite / Sqflite
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Geolocator Plugin
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Image Picker, Path Provider, Share Plus
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }

# Standard Reflection & Annotation preservation
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-dontwarn javax.annotation.**

# Play Store Split / Deferred Components (Flutter engine fallback)
-dontwarn com.google.android.play.core.**

