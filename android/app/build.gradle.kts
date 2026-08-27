import java.util.Properties

// The upload key for Google Play. Kept out of the repo: `android/key.properties` points
// at a keystore in the developer's home directory. Without it (a fresh checkout, CI
// without secrets) the release build falls back to debug signing so it still runs —
// but such a build can never be uploaded to Play, which rejects debug-signed bundles.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tz.co.makutano.makutano_connect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
            // flutter_local_notifications schedules with java.time on old Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "tz.co.makutano.makutano_connect"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            if (keystoreProperties.containsKey("storeFile")) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.containsKey("storeFile")) {
                signingConfigs.getByName("upload")
            } else {
                logger.lifecycle("android/key.properties is absent — release build signed with debug keys, NOT uploadable to Play.")
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Firebase, if this build has been given a project. `google-services.json` is not in
// version control (it identifies one Firebase project, and a fork should use its own),
// so applying the plugin unconditionally would break every build that lacks the file.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle("android/app/google-services.json is absent — building without push.")
}
