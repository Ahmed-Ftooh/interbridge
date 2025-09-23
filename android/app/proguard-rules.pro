# Keep Flutter core and plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Supabase and related serialization libs
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-keep class com.google.gson.** { *; }
-keep class kotlinx.serialization.** { *; }

# Keep Firebase (messaging/analytics if present)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep Agora SDK
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Reduce logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
