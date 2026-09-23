// ====================================================================================================
// ARCHIVO: android/app/build.gradle.kts
// PROJECT JOSH SECURITY
// ====================================================================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.josh.security.josh_security"

    // Se establece explicitamente la API 36 de Android
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility =
            JavaVersion.VERSION_1_8

        targetCompatibility =
            JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget =
            JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId =
            "com.josh.security.josh_security"

        minSdk =
            flutter.minSdkVersion

        // Se establece explicitamente el targetSdk en 36 para cumplir con Google Play
        targetSdk = 36

        versionCode =
            flutter.versionCode

        versionName =
            flutter.versionName
    }

    buildTypes {
        release {
            signingConfig =
                signingConfigs.getByName("debug")
        }
    }

    lint {
        disable += "PropertyEscape"
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}
