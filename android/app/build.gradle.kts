plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.h"
    compileSdk = 34 // 🔥 Hardcode 34 cho chắc chắn
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.h"
        minSdk = 24
        targetSdk = 34 // 🔥 Hardcode 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // 🔥 Bật Multidex
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.android.support:multidex:1.0.3")
}

// --- FIX LỖI DUPLICATE CLASS (Cú pháp Kotlin DSL) ---
configurations.all {
    exclude(group = "com.google.flatbuffers", module = "flatbuffers-java")
}