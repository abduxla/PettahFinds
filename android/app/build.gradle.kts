import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─────────────────────────────────────────────────────────────────────────────
// Release signing resolution — runs at the TOP LEVEL before any Android plugin
// configuration so that a missing value fails fast and visibly rather than
// causing the Android Gradle plugin to silently fall back to debug signing.
//
// Priority:  android/key.properties  (local dev, git-ignored)
//         →  CM_* environment vars   (Codemagic CI — injected by Android code
//                                     signing when keystore is uploaded in the
//                                     Codemagic Flutter workflow editor)
// ─────────────────────────────────────────────────────────────────────────────

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(FileInputStream(keyPropertiesFile))
}

// Helper: return env var value only if it is non-null AND non-empty.
fun env(name: String): String? = System.getenv(name)?.takeIf { it.isNotEmpty() }

// Resolve each signing value: key.properties first, CM_* env var as fallback.
// takeIf guards against key.properties containing empty strings (e.g. a
// partially-filled template) so the env var fallback is still reached.
val releaseKeyAlias      = (keyProperties["keyAlias"]      as? String)?.takeIf { it.isNotEmpty() }
                           ?: env("CM_KEY_ALIAS")
val releaseKeyPassword   = (keyProperties["keyPassword"]   as? String)?.takeIf { it.isNotEmpty() }
                           ?: env("CM_KEY_PASSWORD")
val releaseStorePassword = (keyProperties["storePassword"] as? String)?.takeIf { it.isNotEmpty() }
                           ?: env("CM_KEYSTORE_PASSWORD")
val releaseStorePath     = (keyProperties["storeFile"]     as? String)?.takeIf { it.isNotEmpty() }
                           ?: env("CM_KEYSTORE_PATH")

// ─── Safe diagnostic logging — search "PettahFinds signing" in Codemagic logs ─
val isCI = env("CI") != null || env("CM_BUILD_ID") != null
println("┌─ PettahFinds signing diagnostics ─────────────────────────────────────")
println("│  key.properties found    : ${keyPropertiesFile.exists()}")
println("│  key.properties path     : ${keyPropertiesFile.absolutePath}")
println("│  CM_KEYSTORE_PATH set    : ${env("CM_KEYSTORE_PATH") != null}")
println("│  CM_KEY_ALIAS set        : ${env("CM_KEY_ALIAS") != null}")
println("│  CM_KEYSTORE_PASSWORD set: ${env("CM_KEYSTORE_PASSWORD") != null}")
println("│  CM_KEY_PASSWORD set     : ${env("CM_KEY_PASSWORD") != null}")
println("│  Resolved storeFile      : ${releaseStorePath ?: "<NOT SET — build will fail on CI>"}")
println("│  Resolved keyAlias       : ${releaseKeyAlias  ?: "<NOT SET — build will fail on CI>"}")
println("│  storeFile exists on disk: ${releaseStorePath?.let { File(it).exists() } ?: false}")
println("│  Running in CI           : $isCI")
println("│  signingConfig used      : ${if (!releaseStorePath.isNullOrEmpty()) "release" else "WARNING: storeFile missing"}")
println("└───────────────────────────────────────────────────────────────────────")

// ─── Hard failure on CI — never silently produce a debug-signed artifact ─────
if (isCI) {
    val missing = mutableListOf<String>()
    if (releaseKeyAlias.isNullOrEmpty())      missing += "CM_KEY_ALIAS"
    if (releaseKeyPassword.isNullOrEmpty())   missing += "CM_KEY_PASSWORD"
    if (releaseStorePassword.isNullOrEmpty()) missing += "CM_KEYSTORE_PASSWORD"
    if (releaseStorePath.isNullOrEmpty())     missing += "CM_KEYSTORE_PATH"
    if (missing.isNotEmpty()) {
        throw GradleException(
            "\n\n❌  Android release signing is incomplete. Missing on CI:\n" +
            missing.joinToString("\n") { "      • $it" } + "\n\n" +
            "   → Open Codemagic → your app → Workflow editor → Distribution\n" +
            "     → Android code signing → enable and upload pettahfinds-upload-key.jks\n" +
            "   Key alias : pettahfinds-key\n"
        )
    }
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
            // All values are resolved above at script top-level; they are
            // guaranteed non-null/non-empty on CI (hard failure above) and
            // come from key.properties on a local dev machine.
            keyAlias      = releaseKeyAlias      ?: ""
            keyPassword   = releaseKeyPassword   ?: ""
            storePassword = releaseStorePassword ?: ""
            releaseStorePath?.let { storeFile = file(it) }
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
            // Explicitly use the release signing config — never debug.
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
