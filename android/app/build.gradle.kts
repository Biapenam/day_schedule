import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置（android/key.properties，已被 .gitignore 忽略）。
// Debug 构建不需要正式签名；Release 构建禁止回退到 debug 签名。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val releaseSigningConfigured = keystorePropertiesFile.exists()
if (releaseSigningConfigured) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 直接执行 assembleRelease / bundleRelease 等任务时，尽早给出明确错误，
// 避免生成使用 debug 签名或无法用于升级的正式包。
val releaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.substringAfterLast(':').contains("release", ignoreCase = true)
}
if (releaseBuildRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Release build requires android/key.properties and a release keystore. " +
            "Copy android/key.properties.example and configure your signing credentials."
    )
}

android {
    namespace = "com.biapenam.day_schedule"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.biapenam.day_schedule"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // 始终声明 release 配置，但绝不使用 debug 配置作为回退。
        // 缺少 key.properties 时，直接执行 release 任务会在上方失败；
        // 聚合任务（如 assemble）也会因空的 release 配置而无法签名。
        create("release") {
            if (releaseSigningConfigured) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
