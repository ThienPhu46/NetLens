plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.h"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // 📍 BƯỚC 1: KÍCH HOẠT DESUGARING
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        // Đảm bảo jvmTarget là 1.8
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.example.h"
        // minSdk = 24 đã đúng cho ARCore
        minSdk = 24 
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
    // 📍 BƯỚC 2: THÊM DEPENDENCY CHO DESUGARING
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Các dependencies khác...
    implementation("com.android.support:multidex:1.0.3")
}

// --- ĐOẠN CODE FIX LỖI DUPLICATE CLASS (GIỮ NGUYÊN) ---
configurations.all {
    exclude(group = "com.google.flatbuffers", module = "flatbuffers-java")
}