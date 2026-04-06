# CLAUDE.md - POC Body Measure AI

## Project Overview

iOS SwiftUI app (POC) for body measurement scanning and garment analysis using Apple Vision Framework. Captures body proportions from camera video, classifies body shapes, analyzes garment properties (color, pattern, silhouette), and exports combined styling profiles as JSON.

**Bundle ID:** `com.rene.stylista.BodyMeasureAI`
**Min iOS:** 17.0
**Language:** Swift 5.9+ / SwiftUI

## Architecture

MVVM + Coordinator pattern with singleton services.

```
BodyMeasureAIApp (@main)
  └── AppRootView (auth state dispatch)
      ├── RecoveryView (restore previous device scans)
      └── ContentView (NavigationStack)
          └── AppCoordinator (state + navigation)
              ├── OnboardingView → height + gender input
              ├── BodyCaptureView → camera + Vision pose detection
              ├── ResultsView → measurements display
              ├── MultiAngleBodyScanView → 3-angle scan (front/side/back)
              ├── GarmentCaptureView → photo picker + analysis
              ├── GarmentResultView → garment tags display
              ├── FinalScanResultView → combined profile + export
              └── ValidationModeView → accuracy testing
```

## Key Directories

```
BodyMeasureAI/
├── BodyMeasureAIApp.swift          # App entry point
├── ContentView.swift               # NavigationStack root
├── StylistA/
│   ├── App/AppCoordinator.swift    # Navigation coordinator
│   ├── DesignSystem/               # Typography, spacing, shadows
│   ├── Models/                     # BodyProportionModel, BodyScanResult, GarmentTagModel, ScanSessionModel
│   ├── Services/                   # Vision, Appwrite, Keychain, JSON export
│   ├── ViewModels/                 # BodyCaptureViewModel, GarmentCaptureViewModel, BodyClassificationEngine
│   └── Views/                      # All SwiftUI views
BodyMeasureAITests/                 # Unit tests
BodyMeasureAIUITests/               # UI tests (boilerplate only)
```

## Dependencies

- **Appwrite SDK** - Backend auth + database (endpoint: `https://cloud.appwrite.io/v1`)
- **Vision Framework** - Body pose detection (`VNDetectHumanBodyPoseRequest`) + image classification (`VNClassifyImageRequest`)
- **AVFoundation** - Camera capture session
- **PhotosUI** - Image picker (PHPicker)
- **Security** - Keychain storage

## Build & Run

```bash
# Open in Xcode
open BodyMeasureAI.xcodeproj
# Build: Cmd+B | Run: Cmd+R
# Physical device recommended (camera + Vision required)
```

## Testing

```bash
# Run unit tests
xcodebuild test -project BodyMeasureAI.xcodeproj -scheme BodyMeasureAI -destination 'platform=iOS Simulator,name=iPhone 16'
```

Test files:
- `BodyClassificationEngineTests.swift` - Body shape classification thresholds
- `KeychainManagerTests.swift` - Keychain CRUD operations
- `CameraTimerTests.swift` - Timer persistence and state

## Key Algorithms

### Body Measurement (KeypointNormalizer.swift)
- Converts Vision 0-1 normalized keypoints to real-world cm using user height as scale
- Circumference: Ramanujan elliptical approximation with depth ratios (shoulder: 0.42, hip: 0.62, waist: 0.55)
- Outputs: M1 (shoulder), M2 (hip), M3 (waist), V1 (torso), V2 (legs)
- Confidence threshold: 0.5 minimum per keypoint
- Frame throttle: every 5th frame, 10-frame buffer averaged

### Body Classification (BodyClassificationEngine.swift)
- Women: Hourglass/Rectangle/InvertedTriangle/Triangle/Round + vertical type + petite flag
- Men: Waist prominence / broad shoulders / broad hips detection
- Thresholds: 7.62cm horizontal, 6.35cm vertical tolerance

### Garment Analysis (GarmentClassifierService.swift)
- Uses generic VNClassifyImageRequest (not fashion-trained)
- Maps Vision labels to category/subcategory/pattern/silhouette/length
- Color extraction: 100x100 downsample, 16-bin RGB histogram clustering

## Auth Flow

Device-based anonymous auth via Appwrite:
1. Generate device ID (UDID + timestamp) stored in Keychain
2. Create email: `{deviceId}@anonymous.stylista.app`
3. Password: device ID padded to 8 chars
4. On reinstall with existing Keychain: offers recovery of previous scans

## Design System (DesignSystem.swift)

- Typography: SFont.display (Georgia), .heading (rounded), .body, .mono, .label
- Colors: Asset catalog semantic colors (sBackground, sPrimary, sSecondary, sAccent, etc.)
- Spacing: xs(4) sm(8) md(12) lg(16) xl(24) xxl(32) xxxl(64)

## Conventions

- All models implement `exportJSON` computed property returning `[String: Any]`
- Services are singletons accessed via `.shared`
- Navigation uses `FlowStep` enum with `NavigationStack`
- Views use `@EnvironmentObject` for coordinator access
- Async/await for all async operations (except AuthService which mixes DispatchQueue)
