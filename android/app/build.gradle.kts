import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(f.inputStream())
}

configure<com.android.build.api.dsl.ApplicationExtension> {
    namespace = "de.oppahansi.ltcpro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "de.oppahansi.ltcpro"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProps.getProperty("storeFile") ?: System.getenv("ANDROID_KEYSTORE")
            val storePwd = keystoreProps.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val alias = keystoreProps.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS")
            val keyPwd = keystoreProps.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD")

            require(!storeFilePath.isNullOrBlank()) { "Missing keystore path" }
            require(!storePwd.isNullOrBlank()) { "Missing store password" }
            require(!alias.isNullOrBlank()) { "Missing key alias" }
            require(!keyPwd.isNullOrBlank()) { "Missing key password" }

            storeFile = file(storeFilePath)
            storePassword = storePwd
            keyAlias = alias
            keyPassword = keyPwd
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs["release"]
            isMinifyEnabled = true // Optional: disable minification, adjust as needed
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}
