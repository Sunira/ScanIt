# ScanIt

A family iPhone app that scans documents and photos, uses AI (Claude) to read and sort them, and keeps every word searchable.

- Product decisions: [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md)
- Version 1 build plan: [`docs/V1_BUILD_PLAN.md`](docs/V1_BUILD_PLAN.md)

## Running the app on your Mac

Requirements: Xcode 26 and an iPhone on iOS 26.

1. Install XcodeGen once: `brew install xcodegen`
2. In this folder, generate the Xcode project: `xcodegen generate`
3. Open `ScanIt.xcodeproj` and pick your Apple Developer team under
   *Signing & Capabilities* (or set `DEVELOPMENT_TEAM` in `project.yml`).
4. Choose your iPhone as the run destination and press **Run**.

Re-run `xcodegen generate` after pulling changes, because the Xcode project is generated from `project.yml` and isn't stored in git.

## Automatic builds

Every push is built and tested on GitHub's Macs (`.github/workflows/ios.yml`).
