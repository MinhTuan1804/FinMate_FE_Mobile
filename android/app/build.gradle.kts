plugins {
    id("com.android.application")
    // Compiler Compose cho các widget Jetpack Glance (Luồng 9). Plugin Kotlin Android gốc được
    // flutter-gradle-plugin tự áp dụng (xem local.properties/flutter.kotlinVersion) nên không khai
    // báo lại ở đây.
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.finmate.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.finmate.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Cùng phiên bản flutter_secure_storage 9.2.4 đã kéo vào build; khai báo lại vì implementation của plugin không lộ ra module app.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20231013")

    // Home-screen widgets (Luồng 9) — Jetpack Glance, widget UI dựng bằng Compose, không dùng RemoteViews thủ công.
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
    // W1 — đồng bộ dữ liệu nền định kỳ (WorkManager, native, không qua Flutter engine).
    implementation("androidx.work:work-runtime-ktx:2.9.1")
}
