import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
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
val useReleaseProfileSigning =
    System.getenv("FINN_PROFILE_RELEASE_SIGNING")?.toBooleanStrictOrNull() ?: true

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
            // The local inference runtime targets 64-bit ARM.
            abiFilters += listOf("arm64-v8a")
        }
        externalNativeBuild {
            cmake {
                // The voice shim links the arm64 ONNX Runtime the app ships.
                abiFilters += listOf("arm64-v8a")
            }
        }
    }

    buildFeatures {
        buildConfig = true
    }

    // The text-to-speech shim (src/main/cpp): a small C wrapper around ONNX
    // Runtime that runs the Supertonic voice models.
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    packaging {
        jniLibs {
            // llama.cpp's runtime-dispatched ARM backends are dlopen'ed by
            // filename. They must exist in applicationInfo.nativeLibraryDir,
            // not only as unextracted entries inside base.apk.
            useLegacyPackaging = true
            // Flutter's JNI helper is published for several ABIs even when
            // FinnAI's native inference runtime is arm64-only. A plain
            // `flutter build apk --release` otherwise injects Flutter engine
            // binaries for unsupported ABIs, so strip those copies before
            // APK and Play delivery.
            excludes += setOf(
                "**/armeabi-v7a/*.so",
                "**/x86_64/*.so",
            )
            // The vendored AAR also carries llama.cpp's Vulkan backend
            // (libggml-vulkan.so, ~71 MB uncompressed). FinnAI never selects it
            // on Android: AdaptiveInferenceEngine.accelerateIfAvailable returns
            // null for `Platform.isAndroid` and the planner pins gpuLayers to
            // 0, so the backend is unreachable. It is loaded only through
            // ggml_backend_load_all's directory scan — nothing NEEDs it — so
            // dropping it cannot break the loader; it just is not offered.
            // Removing it roughly halves the native payload of the shipped APK.
            // Keep this in step with the AAR contents in
            // tool/rebuild_llama_android_aar.sh: if Android GPU offload is ever
            // enabled, delete this exclude instead of changing the build.
            excludes += "**/libggml-vulkan.so"
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
            // Physical benchmarks often update a debug-signed install so its
            // private GGUF files remain intact. Set
            // FINN_PROFILE_RELEASE_SIGNING=false for that workflow; normal
            // profile/release validation retains release signing by default.
            if (hasReleaseSigning && useReleaseProfileSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
