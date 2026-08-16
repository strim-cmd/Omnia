package com.omnia.application

/**
 * Static identity of the application, surfaced on the About screen.
 * Version strings mirror the iOS single source of truth
 * (App/Config/Shared.xcconfig: MARKETING_VERSION / CURRENT_PROJECT_VERSION).
 */
data class AppMetadata(
    val name: String,
    val marketingVersion: String,
    val buildNumber: String,
) {
    val versionLabel: String get() = "$marketingVersion ($buildNumber)"
}
