import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.petafinds.petafinds"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            // key.properties is used for local builds (git-ignored, never on CI).
            // On Codemagic the file is absent, so we fall back to the environment
            // variables that Codemagic injects when Android code signing is enabled.
            // Using safe-cast (as?) avoids the NullPointerException that occurs when
            // key.properties is missing and a hard cast (as String) is used instead.
            keyAlias      = (keyProperties["keyAlias"]      as? String) ?: System.getenv("CM_KEY_ALIAS")           ?: ""
            keyPassword   = (keyProperties["keyPassword"]   as? String) ?: System.getenv("CM_KEY_PASSWORD")        ?: ""
            storePassword = (keyProperties["storePassword"] as? String) ?: System.getenv("CM_KEYSTORE_PASSWORD")   ?: ""
            val storePath = (keyProperties["storeFile"]     as? String) ?: System.getenv("CM_KEYSTORE_PATH")
            if (storePath != null) storeFile = file(storePath)
        }
    }

    defaultConfig {
        applicationId = "com.petafinds.petafinds"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
