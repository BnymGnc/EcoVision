pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            // Flutter writes UTF-8 paths; InputStream uses ISO-8859-1 by default.
            file("local.properties").reader(Charsets.UTF_8).use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            // Flutter's plugin loader reads this file as Java Properties bytes.
            // Escape Unicode paths so its ISO-8859-1 reader sees the same SDK.
            if (flutterSdkPath.any { it.code > 127 }) {
                file("local.properties").outputStream().use { properties.store(it, null) }
            }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
