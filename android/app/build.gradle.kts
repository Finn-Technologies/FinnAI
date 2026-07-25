import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
var hasReleaseSigning = false

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    hasReleaseSigning = true
} else if (System.getenv("KEYSTORE_PATH") != null) {
    keystoreProperties["storeFile"] = System.getenv("KEYSTORE_PATH")
    keystoreProperties["storePassword"] = System.getenv("KEYSTORE_PASSWORD")
    keystoreProperties["keyAlias"] = System.getenv("KEY_ALIAS")
    keystoreProperties["keyPassword"] = System.getenv("KEY_PASSWORD")
    hasReleaseSigning = true
}

android {
    namespace = "com.abhiflex.finnai"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.abhiflex.finnai"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // Bonsai's optimized mobile kernels target 64-bit ARM.
            abiFilters += listOf("arm64-v8a")
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Ensure release build never falls back quietly to debug signing certificate.
                signingConfig = null
            }
        }
    }
}

gradle.taskGraph.whenReady {
    if (hasTask(":app:assembleRelease") || hasTask(":app:bundleRelease")) {
        if (!hasReleaseSigning) {
            throw GradleException(
                "Release signing configuration is missing! " +
                "Please populate 'android/key.properties' or set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, and KEY_PASSWORD environment variables."
            )
        }
    }
}

dependencies {
    implementation(files("libs/llama-cpp-dart.aar"))
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
