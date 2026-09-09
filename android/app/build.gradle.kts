plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "la.laostay.partner_app"
    compileSdk = flutter.compileSdkVersion
    // Left at Flutter's default on purpose. image_picker, path_provider and
    // sqflite each *warn* that they want NDK 27.0.12077973, but none of them
    // ships native code this app uses, and the build succeeds without it.
    // Pinning 27 makes Gradle download roughly 3 GB of NDK — worth doing only
    // if a plugin actually fails to link.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "la.laostay.partner_app"
        // 23, not Flutter's default 21: flutter_secure_storage needs it, and
        // the tokens it holds are worth the two dropped Android versions —
        // 5.0/5.1 are well under 1% of devices. Raising it here rather than
        // forcing the library through with tools:overrideLibrary, which would
        // only move the failure to runtime.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
