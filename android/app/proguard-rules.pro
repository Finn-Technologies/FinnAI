# Flutter & Platform embedding rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# App entrypoints and Native services
-keep class com.abhiflex.finnai.MainActivity { *; }
-keep class com.abhiflex.finnai.ModelDownloadService { *; }
-keep class com.abhiflex.finnai.** { *; }

# JNI & Native methods
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Preserve annotations and type signatures
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Suppress harmless warnings for optional JDK and Play Core packages
-dontwarn javax.crypto.**
-dontwarn java.awt.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
