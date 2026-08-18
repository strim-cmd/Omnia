package com.omnia.app

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Regression guard: the INTERNET permission is required for provider network calls.
 * If this test fails, a production APK would silently fail all network requests.
 */
class ManifestPermissionTest {

    @Test
    fun androidManifest_declaresInternetPermission() {
        val manifest = File("src/main/AndroidManifest.xml")
        assertTrue("AndroidManifest.xml must exist", manifest.exists())

        val content = manifest.readText()
        assertTrue(
            "AndroidManifest.xml must declare android.permission.INTERNET",
            content.contains("android.permission.INTERNET"),
        )
    }

    @Test
    fun androidManifest_declaresNoUnnecessaryPermissions() {
        val manifest = File("src/main/AndroidManifest.xml")
        val content = manifest.readText()

        val allowedPermissions = setOf(
            "android.permission.INTERNET",
        )

        val regex = Regex("""android:name="(android\.permission\.[^"]+)"""")
        val found = regex.findAll(content).map { it.groupValues[1] }.toList()

        for (perm in found) {
            assertTrue(
                "Unexpected permission in manifest: $perm. Only $allowedPermissions are allowed.",
                perm in allowedPermissions,
            )
        }
    }
}
