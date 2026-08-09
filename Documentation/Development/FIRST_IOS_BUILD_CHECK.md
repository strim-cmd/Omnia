# First iOS Build Check Checklist

This checklist covers the preparation for the first iOS build of the Omnia application.

## 1. Project Configuration (Xcode: `App/Omnia.xcodeproj`)
- [ ] **Targets**: Verify `OmniaiOS` target is configured correctly.
- [ ] **Deployment Target**: Ensure `IPHONEOS_DEPLOYMENT_TARGET` is set to `16.0`.
- [ ] **Bundle Identifier**: Verify `PRODUCT_BUNDLE_IDENTIFIER` is `com.omnia.ios`.
- [ ] **Info.plist**: Confirm `Omnia/Info.plist` is being utilized and contains necessary iOS-specific keys (e.g., `NSLocalNetworkUsageDescription` is already there).
- [ ] **Asset Catalog**: Ensure `AppIcon` is correctly assigned in `Assets.xcassets`.
- [ ] **Entitlements**: Check `Omnia/Omnia.entitlements` (if applicable for iOS).

## 2. Build Configurations (.xcconfig)
- [ ] **Shared Settings**: Verify `App/Config/Shared.xcconfig` contains correct `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
- [ ] **Signing**: `CODE_SIGN_IDENTITY` is currently set to `-` (ad-hoc). For the first App Store/TestFlight build, this must be updated to a distribution certificate.

## 3. Dependencies
- [ ] **Package.swift**: Verify that all local packages are correctly linked to the `OmniaiOS` target in Xcode.

## 4. Build Steps
1. Open `Omnia.xcworkspace` in Xcode.
2. Select the `OmniaiOS` scheme.
3. Select a real iOS device or simulator.
4. Product -> Clean Build Folder.
5. Product -> Build.

## 5. Potential Issues to Check
- **Missing Info.plist Keys**: iOS may require specific keys not present in `Omnia/Info.plist`.
- **Assets**: The current `Assets.xcassets` appears empty. Ensure proper icon sets are added.
- **Signing**: Automatic signing might fail if the bundle identifier `com.omnia.ios` is not registered in your Apple Developer account.
