import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Applied imperatively (not in the plugins {} block above) and only once
// google-services.json exists: the Google Services plugin fails the build
// outright if that file is missing, which would break every local build
// (including `flutter run`) for anyone who hasn't completed the one-time
// Firebase app registration yet. CI always has the file since it's committed.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing: values come from key.properties (gitignored, never
// committed) rather than being hardcoded. Missing file -> release builds
// silently fall back to the pre-existing debug signingConfig further down,
// so `flutter run --release` keeps working for anyone without release
// secrets.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigningConfig = keystorePropertiesFile.exists()
if (hasReleaseSigningConfig) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.atmscout.app.atm_scout"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.atmscout.app.atm_scout"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real release signing once key.properties exists (see above);
            // falls back to debug signing otherwise so `flutter run --release`
            // keeps working without release secrets present.
            signingConfig = signingConfigs.getByName(
                if (hasReleaseSigningConfig) "release" else "debug"
            )
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
    // Required for the Theme.MaterialComponents.* base theme (mapbox_maps_flutter's
    // compass/logo/attribution plugin views need an AppCompat/MaterialComponents theme).
    implementation("com.google.android.material:material:1.9.0")
}
