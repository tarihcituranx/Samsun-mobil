import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}

android {
    namespace = "com.tarihcituranx.samsun_ulasim"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: System.getenv("KEY_ALIAS") ?: "samsun"
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: System.getenv("KEY_PASSWORD") ?: ""
            storeFile = (keystoreProperties.getProperty("storeFile")
                ?: System.getenv("STORE_FILE"))?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: System.getenv("STORE_PASSWORD") ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.tarihcituranx.samsun_ulasim"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists() || System.getenv("STORE_FILE") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
