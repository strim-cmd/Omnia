plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

val realUserHome = System.getProperty("user.home") ?: ""
val asciiTestHome = if (
    System.getProperty("os.name").startsWith("Windows", ignoreCase = true) &&
    realUserHome.any { it.code > 0x7F }
) {
    "C:\\OmniaTestHome"
} else {
    null
}

subprojects {
    tasks.withType<Test>().configureEach {
        if (name.endsWith("ReleaseUnitTest")) {
            enabled = false
        }
        asciiTestHome?.let { systemProperty("user.home", it) }
    }
}
