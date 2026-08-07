# Code Signing and Notarization Strategy

## Overview
This document defines the code signing and notarization strategy for the Omnia application, ensuring reproducible, secure, and distributable builds for both macOS and iOS platforms.

## Development Signing
- All local development builds use **Automatic Signing** with the project's development team.
- This applies to:
    - Debug/Release builds run via Xcode/`xcodebuild` locally.
    - Sideloaded builds for testing on registered development devices (iOS).

## macOS Distribution
- **Signing**: Developer ID Application identity.
- **Hardened Runtime**: Enabled with `--options runtime` for notarization compatibility.
- **Notarization**: Performed via `notarytool` post-build.
- **Stapling**: The notarization ticket is stapled to the application bundle.
- **Artifacts**: Notarized `.zip` and `.dmg`.

## iOS Distribution
- **App Store/TestFlight**: Provisioned with App Store distribution profiles. Authenticated via CI API key.
- **Ad-hoc/Sideloading**: Provisioned with development/ad-hoc profiles.
- **Artifacts**: `.ipa` (App Store) and `.ipa` (Ad-hoc).

## Entitlements
Entitlements are declared explicitly in the Xcode project and verified according to `SECURITY.md`.
- **App Sandbox**: Required for macOS distribution.
- **Hardened Runtime**: Required for Developer ID.
- **Keychain Access**: Required for secure credential storage.
- **Outgoing Network**: Required for provider API access.

## Credential Handling
- All certificates, private keys, provisioning profiles, and API keys are stored exclusively as **GitHub Actions Secrets**.
- No sensitive material is ever committed to the repository.
- Pipeline steps that require secrets check for their existence and skip if missing, ensuring builds remain reproducible even without distribution-level credentials.
