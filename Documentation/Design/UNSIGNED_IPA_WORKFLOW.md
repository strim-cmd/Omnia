# Unsigned IPA Workflow for Third-Party Signing

## Overview
This document outlines the workflow for obtaining an unsigned IPA artifact from the Omnia release pipeline. This artifact is intended for users who wish to apply third-party signing (e.g., Scarlet, ESign) for sideloading onto iOS devices without the need for Apple distribution certificates.

## Prerequisites
- The release pipeline has completed a run.
- The `omnia-VERSION` artifact bundle is available for download from the GitHub Actions run summary.

## Workflow
1. **Pipeline Execution**: The automated release pipeline generates an unsigned `.ipa` file as part of its normal execution.
2. **Artifact Download**:
    - Navigate to the **Actions** tab in the repository.
    - Select the successful release pipeline run.
    - Scroll down to the **Artifacts** section and download the `omnia-VERSION` zip file.
3. **Extraction**: Extract the zip archive to locate the `ios/unsigned` directory.
4. **Third-Party Signing**:
    - Use your chosen third-party signing tool to import the unsigned `.ipa` file.
    - Apply your own developer certificates/profiles as required by the tool.
    - Sign and install the resulting IPA onto your iOS device.

## Warnings
- Unsigned or third-party signed applications are not reviewed by Apple and may pose security risks.
- Ensure the signing source is trusted.
- Omnia assumes no responsibility for issues arising from third-party signing or installation methods.
