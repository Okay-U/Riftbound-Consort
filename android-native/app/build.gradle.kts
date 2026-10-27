import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

android {
    namespace = "pitopia.riftcount"
    compileSdk = 36

    defaultConfig {
        // Same id as the Skip app so the Play update keeps the users and their files.
        applicationId = "pitopia.Riftcount"
        minSdk = 28
        targetSdk = 36
        versionCode = 10
        versionName = "4.0.0"
        manifestPlaceholders["appLabel"] = "Riftcount"
    }

    // Okay's upload key (gitignored keystore.properties next to this file, same format as the Skip app).
    val keystoreFile = file("keystore.properties")
    signingConfigs {
        if (keystoreFile.isFile) {
            create("upload") {
                val props = Properties().apply { keystoreFile.inputStream().use(::load) }
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            // Installs next to the old Skip app on the emulator.
            applicationIdSuffix = ".native"
            manifestPlaceholders["appLabel"] = "Riftcount native"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.findByName("upload")
        }
        // Release code (R8) signed with the debug key, next to the old app: for judging speed on the emulator.
        create("staging") {
            initWith(getByName("release"))
            applicationIdSuffix = ".native"
            manifestPlaceholders["appLabel"] = "Riftcount native"
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += "release"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    testOptions {
        // android.util.Log and friends return defaults in JVM unit tests.
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.05.01"))
    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")

    testImplementation("junit:junit:4.13.2")
}
