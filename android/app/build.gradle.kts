plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.church_reimbursement"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어에서 앱을 구분하는 고유 ID. iOS 번들 ID(ios/Runner.xcodeproj)와 같은 값으로 맞춤.
        // com.example.*은 Play Store가 거부하므로 교회/개인 이름이 아닌 앱 이름 기준으로 정함
        // (여러 교회가 쓸 수 있게). 출시 후에는 바꿀 수 없음 - 바꾸면 완전히 다른 앱이 됨.
        // namespace(위)는 코드 내부용 이름이라 그대로 둠 (바꾸면 MainActivity.kt 폴더까지 옮겨야 함)
        applicationId = "app.churchreimbursement"
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
