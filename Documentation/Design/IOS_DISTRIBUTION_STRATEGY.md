# iOS Distribution Strategy

## Overview
This document defines the iOS distribution strategy for Omnia, covering IPA generation, TestFlight distribution, and ad-hoc sideloading.

## IPA Generation
IPA files are generated reproducibly using `xcodebuild` from the archived application.

### Export Methods
1. **App Store (TestFlight)**: Configured for distribution via App Store Connect. Uses an App Store distribution provisioning profile.
2. **Ad-hoc/Development (Apple Sideloading)**: Configured for installation on registered testing devices. Uses an ad-hoc or development provisioning profile.
3. **Unsigned IPA (Third-Party Signing)**: An unsigned IPA generated for use with third-party tools (e.g., Scarlet, ESign). Does not use provisioning profiles. Because `xcodebuild -exportArchive` requires a signing team embedded in the archive, the unsigned IPA is instead packaged directly from the (unsigned) archived `.app` into a `Payload/` directory.

### Configuration
Export options are defined in:
- `.github/export/ios-appstore.plist`
- `.github/export/ios-adhoc.plist`

The unsigned IPA is produced by the `Export iOS IPA (unsigned for third-party signing)` pipeline step (direct `Payload/` packaging from the archive; no export options plist).

## Distribution Workflows

### TestFlight
- **Trigger**: Pushed tag `v*` on the main branch or manual workflow dispatch.
- **Process**:
    1. Build and archive the iOS scheme.
    2. Export the IPA using `ios-appstore.plist`.
    3. Upload to App Store Connect using `altool` or `xcrun notarytool` (when available) authenticated with a GitHub Actions Secret API key.

### Apple Sideloading (Ad-hoc)
- **Trigger**: Manual build/export requested for testing on registered devices.
- **Process**:
    1. Build and archive the iOS scheme locally or via CI.
    2. Export the IPA using `ios-adhoc.plist`.
    3. Install the IPA on a registered device via Apple Configurator or Xcode Devices window.

### Unsigned IPA (Third-Party Signing)
- **Trigger**: Produced automatically by the CI pipeline for every release.
- **Process**:
    1. Download the unsigned IPA from the CI pipeline artifacts.
    2. Follow the instructions in `Documentation/Design/UNSIGNED_IPA_WORKFLOW.md` to apply third-party signing.
