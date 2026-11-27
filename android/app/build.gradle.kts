import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Google Play upload signing -------------------------------------------
// Release builds use a real upload keystore when one is configured, and fall
// back to the debug keystore otherwise so local sideload builds and CI runs
// without secrets keep working unchanged.
//
// Configuration comes from (in priority order):
//   1. android/key.properties  (local builds; gitignored, never commit it)
//      Keys: storePassword, keyPassword, keyAlias, storeFile
//      storeFile is resolved relative to android/app/ (e.g. "upload-keystore.jks")
//      or as an absolute path.
//   2. Environment variables   (CI; set via GitHub Secrets, see
//      .github/workflows/build-apk.yml and docs/PLAY_RELEASE.md)
//      KEYSTORE_FILE, KEYSTORE_PASSWORD, KEYSTORE_ALIAS, KEYSTORE_KEY_PASSWORD
//      (KEY_ALIAS / KEY_PASSWORD / STORE_PASSWORD are accepted as aliases.)
//
// With Play App Signing, Google holds the app signing key and this upload
// key is only used to sign the AAB/APK you upload. Back up the upload
// keystore and its passwords — losing them means you must request an upload
// key reset from Play Console before you can publish updates.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun signingProp(name: String): String? {
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }?.let { return it }
    return when (name) {
        "storeFile" -> System.getenv("KEYSTORE_FILE")
        "storePassword" -> System.getenv("KEYSTORE_PASSWORD") ?: System.getenv("STORE_PASSWORD")
        "keyAlias" -> System.getenv("KEYSTORE_ALIAS") ?: System.getenv("KEY_ALIAS")
        "keyPassword" -> System.getenv("KEYSTORE_KEY_PASSWORD") ?: System.getenv("KEY_PASSWORD")
        else -> System.getenv(name)
    }?.takeIf { it.isNotBlank() }
}

val releaseStoreFilePath = signingProp("storeFile")
val releaseStorePassword = signingProp("storePassword")
val releaseKeyAlias = signingProp("keyAlias")
val releaseKeyPassword = signingProp("keyPassword")
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()

if (!hasReleaseSigning) {
    logger.lifecycle(
        "Play release signing not configured (android/key.properties or KEYSTORE_* env vars missing); " +
            "release builds will use the debug keystore. See docs/PLAY_RELEASE.md"
    )
}

android {
    namespace = "com.westviewhs.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.westviewhs.app"
        // API 24+ is required by the home screen widget (RemoteViews countdown Chronometer).
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Play Store / long-lived sideload: upload keystore when configured
            // (see above). Otherwise debug signing so `flutter build apk
            // --release` still produces an installable sideload APK locally
            // and in CI without secrets.
            signingConfig =
                if (hasReleaseSigning) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
