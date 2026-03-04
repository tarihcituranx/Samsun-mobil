# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep HTTP/networking classes
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**

# Keep sqflite
-keep class com.tekartik.sqflite.** { *; }

# Keep geolocator
-keep class com.baseflow.geolocator.** { *; }

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
