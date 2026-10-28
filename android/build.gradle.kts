group = "io.fishjam.client"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "io.fishjam.client"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 23
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Provided at runtime by flutter_webrtc (WebRTC) and the Flutter embedding (AndroidX).
// compileOnly: the app keeps the single copy that flutter_webrtc packages.
// flutter_webrtc 1.6.2 uses io.github.webrtc-sdk:android:150.7871.01. Gradle
// requires a version on this line, so update it when bumping flutter_webrtc
// in pubspec.yaml.
dependencies {
    compileOnly(project(":flutter_webrtc"))
    compileOnly("io.github.webrtc-sdk:android:150.7871.01")
    compileOnly("androidx.fragment:fragment:1.7.1")
}
