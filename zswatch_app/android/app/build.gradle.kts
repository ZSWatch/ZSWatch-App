plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

data class ReleaseKeystoreConfig(
    val propertiesFilePath: String,
    val keyAlias: String,
    val keyPassword: String,
    val storePassword: String,
    val storeFilePath: String,
)

fun tryLoadReleaseKeystoreConfig(propertiesFilePath: String): ReleaseKeystoreConfig? {
    val propertiesFile = rootProject.file(propertiesFilePath)
    if (!propertiesFile.exists()) return null

    val properties = Properties()
    propertiesFile.inputStream().use { properties.load(it) }

    val keyAlias = properties.getProperty("keyAlias")?.trim().orEmpty()
    val keyPassword = properties.getProperty("keyPassword")?.trim().orEmpty()
    val storePassword = properties.getProperty("storePassword")?.trim().orEmpty()
    val storeFilePath = properties.getProperty("storeFile")?.trim().orEmpty()
    if (keyAlias.isBlank() || keyPassword.isBlank() || storePassword.isBlank() || storeFilePath.isBlank()) {
        return null
    }

    // storeFile is typically set relative to android/app/ (e.g. ../upload-keystore.jks),
    // but absolute paths are supported too.
    val storeFile = project.file(storeFilePath)
    if (!storeFile.exists()) return null

    return ReleaseKeystoreConfig(
        propertiesFilePath = propertiesFilePath,
        keyAlias = keyAlias,
        keyPassword = keyPassword,
        storePassword = storePassword,
        storeFilePath = storeFilePath,
    )
}

// Prefer android/key.properties, but fall back to the Flutter project root key.properties.
val releaseKeystoreConfig =
    tryLoadReleaseKeystoreConfig("key.properties")
        ?: tryLoadReleaseKeystoreConfig("../key.properties")

val hasReleaseKeystore = releaseKeystoreConfig != null

android {
    namespace = "dev.zswatch.app"
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
        applicationId = "com.zswatch.app"
        // minSdk 21 required for BLE reliability (flutter_blue_plus requirement)
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = releaseKeystoreConfig!!.keyAlias
                keyPassword = releaseKeystoreConfig.keyPassword
                storeFile = project.file(releaseKeystoreConfig.storeFilePath)
                storePassword = releaseKeystoreConfig.storePassword
            }
        }
    }

    buildTypes {
        release {
            // If a release keystore is configured via android/key.properties, sign properly.
            // Otherwise fall back to debug signing (fine for local testing, not ideal for releases).
            signingConfig = if (hasReleaseKeystore) {
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
