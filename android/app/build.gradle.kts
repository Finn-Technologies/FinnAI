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
val signingEnvironmentNames = listOf(
    "KEYSTORE_PATH",
    "KEYSTORE_PASSWORD",
    "KEY_ALIAS",
    "KEY_PASSWORD",
)
val configuredSigningEnvironment =
    signingEnvironmentNames.associateWith { System.getenv(it) }

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    hasReleaseSigning = true
} else if (configuredSigningEnvironment.values.any { !it.isNullOrBlank() }) {
    val missingSigningEnvironment = configuredSigningEnvironment
        .filterValues { it.isNullOrBlank() }
        .keys
    if (missingSigningEnvironment.isNotEmpty()) {
        throw GradleException(
            "Incomplete release signing environment. Missing: " +
                missingSigningEnvironment.joinToString(", ")
        )
    }
    keystoreProperties["storeFile"] = configuredSigningEnvironment.getValue("KEYSTORE_PATH")!!
    keystoreProperties["storePassword"] =
        configuredSigningEnvironment.getValue("KEYSTORE_PASSWORD")!!
    keystoreProperties["keyAlias"] = configuredSigningEnvironment.getValue("KEY_ALIAS")!!
    keystoreProperties["keyPassword"] = configuredSigningEnvironment.getValue("KEY_PASSWORD")!!
    hasReleaseSigning = true
}

if (hasReleaseSigning) {
    val requiredSigningProperties =
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    val missingSigningProperties = requiredSigningProperties.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missingSigningProperties.isNotEmpty()) {
        throw GradleException(
            "Incomplete release signing configuration. Missing: " +
                missingSigningProperties.joinToString(", ")
        )
    }
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

    packaging {
        jniLibs {
            // Flutter's JNI helper is published for several ABIs even when
            // FinnAI's native inference runtime is arm64-only. A plain
            // `flutter build apk --release` otherwise injects Flutter engine
            // binaries for unsupported ABIs, so strip those copies before
            // APK and Play delivery.
            excludes += setOf(
                "**/armeabi-v7a/*.so",
                "**/x86_64/*.so",
            )
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
        getByName("profile") {
            // Profile builds are the physical-device inference benchmark
            // surface. Reuse the upload key when available so an instrumented
            // APK can update a release-signed install without deleting its
            // private GGUF files or prefix-state evidence.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
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
