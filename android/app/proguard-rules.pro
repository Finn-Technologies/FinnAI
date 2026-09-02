# FinnAI release (R8) rules.
#
# Keep this file conservative: release APKs are validated on physical devices
# after signing, and over-shrinking JNI/reflection-reached classes fails at
# runtime rather than at build time. Do not widen these rules back to
# package-wide blanket keeps (`com.abhiflex.finnai.** { *; }`) without a
# device-verified release build.

# Flutter embedding. The engine's native code (libflutter.so) and the plugin
# mechanism reach embedding classes by name through JNI and reflection, so
# Flutter's documented standard keep set applies. A single io.flutter.** rule
# is equivalent to the previous per-package lines (io.flutter.app/plugin/
# util/view/plugins), which were strict subsets of it.
-keep class io.flutter.** { *; }

# Manifest components. MainActivity and ModelDownloadService are instantiated
# by the Android framework / Flutter embedding via class-name reflection.
# AGP's generated aapt_rules.txt already keeps them from AndroidManifest.xml;
# these explicit rules document the requirement and guard against tooling
# changes. Framework-facing members (lifecycle overrides, channel handlers)
# stay live through the component superclasses, so only the constructor needs
# pinning here.
-keep class com.abhiflex.finnai.MainActivity { <init>(); }
-keep class com.abhiflex.finnai.ModelDownloadService { <init>(); }

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
