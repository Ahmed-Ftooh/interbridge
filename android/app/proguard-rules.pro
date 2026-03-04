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

# Google Play Core — Flutter references the legacy monolithic API but we use
# the modular Play libraries. Suppress the missing-class warnings from R8.
-dontwarn com.google.android.play.core.**

# Stripe — the SDK bundles React-Native push-provisioning stubs that reference
# classes not shipped in the Flutter Stripe package. Safe to ignore.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.**

# Reduce logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
