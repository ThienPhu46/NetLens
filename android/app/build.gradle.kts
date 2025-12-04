plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.h" // (Hoặc tên package của bạn)
    compileSdk = flutter.compileSdkVersion
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
        minSdk = 24 // ARCore yêu cầu tối thiểu 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // Các dependencies khác...
    implementation("com.android.support:multidex:1.0.3")
}

// --- ĐOẠN CODE FIX LỖI DUPLICATE CLASS (THÊM VÀO ĐÂY) ---
configurations.all {
    exclude(group = "com.google.flatbuffers", module = "flatbuffers-java")
}