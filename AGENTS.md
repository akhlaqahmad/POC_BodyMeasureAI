# AGENTS.md — POC_BodyMeasureAI (iOS)

This file is for AI coding agents (Claude Code, Cursor, Codex, Windsurf). Read it before making changes.

## Project Overview

POC iOS app that captures body measurements and garment tags from photos using on-device Vision and exports a session JSON to the admin backend. SwiftUI, single linear flow (no tab bar). The product name is "BodyMeasureAI" — the in-app feature folder is named `StylistA` for legacy reasons; do not rename it.

## Tech Stack

- Language: Swift 5.0
- UI: SwiftUI
- Vision: `Vision.framework` (`VNDetectHumanBodyPoseRequest`, segmentation)
- Audio: `AVFoundation` (camera + speech guidance)
- Concurrency: `@MainActor`, `Combine`, `async/await`
- Tests: Swift Testing framework (`import Testing`, `@Test`)
- Deployment target: iOS 26.2 (per `BodyMeasureAI.xcodeproj/project.pbxproj`)
- Devices: iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). A watchOS skeleton exists but is not wired up.
- Package manager: SPM (none configured today, but if dependencies are added, use SPM — **do not introduce CocoaPods or Carthage**)

## Repository Structure

```
POC_BodyMeasureAI/
├── BodyMeasureAI.xcodeproj/        # Xcode project. Single-project build.
├── BodyMeasureAI/                  # Main app target source.
│   ├── BodyMeasureAIApp.swift      # @main entry point.
│   ├── ContentView.swift           # Root nav host; injects AppCoordinator.
│   ├── Info.plist                  # ATS exceptions for localhost only.
│   ├── Assets.xcassets/            # Semantic colors (sAccent/sPrimary/...) and instruction images.
│   ├── Shared/                     # Empty placeholder for cross-target code.
│   └── StylistA/                   # All feature code lives here. Do NOT rename.
│       ├── App/
│       │   └── AppCoordinator.swift            # @MainActor flow + upload state machine.
│       ├── Models/                             # Codable domain types. Source of truth for upload JSON.
│       │   ├── BodyProportionModel.swift
│       │   ├── BodyScanResult.swift            # exportJSON shape — backend Zod mirrors this.
│       │   ├── ExtractionReport.swift
│       │   ├── GarmentTagModel.swift
│       │   ├── Gender.swift                    # rawValue is the wire string (lower snake_case).
│       │   ├── ScanHistoryModels.swift
│       │   ├── ScanMode.swift
│       │   └── ScanSessionModel.swift          # exportJSON shape — backend Zod mirrors this.
│       ├── Services/                           # Stateless processing + I/O.
│       │   ├── AppLog.swift                    # os.Logger categories. Use these, do not `print`.
│       │   ├── BackendAPIClient.swift          # URLSession wrapper for POST /api/sessions.
│       │   ├── BackendConfig.swift             # Resolves base URL (Info.plist override → production).
│       │   ├── DeviceIdentity.swift            # x-device-id provider.
│       │   ├── GarmentClassifierService.swift
│       │   ├── GarmentColorExtractor.swift
│       │   ├── GarmentFitComparisonService.swift
│       │   ├── GarmentMeasurementService.swift
│       │   ├── JSONExportService.swift
│       │   ├── KeypointNormalizer.swift        # 2D Vision keypoints → cm via height anchor.
│       │   ├── LandmarkSlicer.swift
│       │   ├── SilhouetteSegmenter.swift
│       │   └── SpeechGuidanceService.swift
│       ├── ViewModels/                         # ObservableObject, @MainActor.
│       │   ├── BodyCaptureViewModel.swift
│       │   ├── BodyClassificationEngine.swift
│       │   └── GarmentCaptureViewModel.swift
│       ├── Views/                              # SwiftUI screens + small modifiers.
│       │   ├── Instructions/                   # Pre-scan walkthrough screens.
│       │   ├── BodyCaptureView.swift
│       │   ├── FinalScanResultView.swift
│       │   ├── GarmentCaptureView.swift
│       │   ├── GarmentResultView.swift
│       │   ├── KeepScreenAwakeModifier.swift
│       │   ├── MultiAngleBodyScanView.swift
│       │   ├── OnboardingView.swift
│       │   ├── ResultsView.swift
│       │   ├── ScanHistoryDetailView.swift
│       │   ├── ScanHistoryView.swift
│       │   ├── SyncStatusBadge.swift
│       │   ├── TwoAngleScanView.swift
│       │   └── ValidationModeView.swift
│       └── DesignSystem/
│           └── DesignSystem.swift              # Tokens (colors/spacing/typography). Use these, not hardcoded values.
├── BodyMeasureAITests/             # Swift Testing unit tests. Currently a stub.
├── BodyMeasureAIUITests/           # XCUITest UI tests.
├── BodyMeasureAIWatch/             # watchOS asset shell. Not active — do not build features here without asking.
├── BodyMeasureAIWatch Watch App/   # watchOS app shell. Same as above.
├── TestSamples/                    # Front+side reference photos used for Vision pipeline tuning.
├── PLAN.md                         # iOS ↔ Backend integration plan. Living doc.
├── README.md                       # Human-facing project intro.
└── AI_DOMAIN_ROLES.md              # Old AGENTS.md content (domain doc, not coding-agent guide). Leave in place.
```

## Architecture Conventions

- **MVVM + Coordinator.** Views are SwiftUI structs; ViewModels conform to `ObservableObject` and run on `@MainActor`. The single `AppCoordinator` holds top-level state (`bodyResult`, `garmentResult`, `uploadStatus`) and owns navigation via a `Binding<NavigationPath>` from `ContentView`.
- **Feature root is `StylistA/`.** All new feature code lives under `BodyMeasureAI/StylistA/<Layer>/`. Do not create new top-level folders inside `BodyMeasureAI/` — keep `Shared/` empty unless the user asks for cross-target code.
- **Layer rules:**
  - `Models/` — pure value types, `Codable` where they cross the wire. No business logic, no I/O.
  - `Services/` — stateless or single-responsibility classes. Vision, networking, JSON, audio. No SwiftUI imports.
  - `ViewModels/` — `@MainActor`, expose `@Published` state, call services, compose models for views.
  - `Views/` — SwiftUI only. No direct service calls; talk to a ViewModel or `AppCoordinator`.
  - `DesignSystem/` — color tokens, spacing, typography. Views must consume these, not hardcoded values.
- **JSON export is the contract.** `BodyScanResult.exportJSON` and `ScanSessionModel.exportJSON` define the upload shape. Backend Zod mirrors them. Never change one without changing the other (see [PLAN.md](PLAN.md)).
- **Logging.** Use `AppLog` categories from [Services/AppLog.swift](BodyMeasureAI/StylistA/Services/AppLog.swift) (`AppLog.lifecycle`, etc.). Do not call `print` in committed code.
- **Concurrency.** ViewModels and `AppCoordinator` are `@MainActor`. Networking uses `URLSession` `async` APIs in `BackendAPIClient`. Long-running CV work runs off-main and dispatches results back via `await MainActor.run`.

## Naming Conventions

- Files: `PascalCase.swift`, named for the primary type they declare (`BodyCaptureViewModel.swift`, `KeypointNormalizer.swift`).
- Types: `UpperCamelCase`. View files end in `View`, view models in `ViewModel`, services in `Service` (or a descriptive noun like `Normalizer`/`Slicer`).
- Cases for enums that cross the wire: lower snake_case raw values (`case nonBinary = "non_binary"`). The Swift case is camelCase; the rawValue matches the Postgres enum.
- Asset color names: `s` prefix for semantic tokens (`sAccent`, `sBackground`, `sSurfaceElevated`).

## Build, Run, and Test Commands

Open in Xcode:

```bash
open BodyMeasureAI.xcodeproj
```

CLI build (sanity check before commit):

```bash
xcodebuild -project BodyMeasureAI.xcodeproj \
  -scheme BodyMeasureAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

Run unit + UI tests:

```bash
xcodebuild -project BodyMeasureAI.xcodeproj \
  -scheme BodyMeasureAI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

End-to-end smoke against local backend (the canonical loop — see [PLAN.md](PLAN.md)):

1. Terminal 1: `cd ../POC_BodyMeasureAI-backend && npm run dev`
2. Build & run the iOS app in the **simulator** (only the simulator can hit `localhost`; ATS exception is simulator-only by design).
3. Complete a scan; watch `SyncStatusBadge` go `SYNCING → SYNCED`.
4. Open `http://localhost:3000/sessions` — the row should appear at the top.

For physical-device testing, set `BACKEND_BASE_URL` in `Info.plist` to a LAN IP or the Vercel URL (`https://bodymeasureai-admin.vercel.app`).

## Agent Workflow Rules

Before writing code:

- Read [PLAN.md](PLAN.md) if the task touches uploads, networking, or the iOS↔backend contract.
- Read the model file you plan to extend (`BodyScanResult.swift`, `ScanSessionModel.swift`, `GarmentTagModel.swift`) — these define the wire shape.
- Grep for an existing service or component before adding a new one. Reuse `KeypointNormalizer`, `BackendAPIClient`, `AppLog` rather than re-rolling.
- If the task says "depth," "mesh," "LiDAR," or "ARKit," stop and read [../docs/3d-body-mesh-feasibility-plan.md](../docs/3d-body-mesh-feasibility-plan.md). None of that exists in-repo today.

When adding a feature:

- New screen → add a `<Name>View.swift` in `Views/`, a `<Name>ViewModel.swift` in `ViewModels/`, and a `FlowStep` case in `AppCoordinator`. Wire navigation through `appendToPath(_:)`.
- New service → drop in `Services/`, accept dependencies via init, no SwiftUI imports.
- New wire-format field → update the relevant `Models/` type, update `exportJSON`, then update the backend's Zod schema and Drizzle table in the same task.

When modifying existing code:

- Preserve the `@MainActor` annotations on coordinators and view models.
- If a value crosses the wire, confirm the rawValue matches the Postgres enum.
- Update inline comments only if the existing comment is now wrong; do not add narration.

## What NOT to Do

- Do not introduce CocoaPods, Carthage, or Bazel. SPM only (and currently no deps).
- Do not add `Vision`-depth, `ARKit`, or LiDAR code paths. The pipeline is monocular 2D. A 3D extension is under evaluation only — do not write speculative scaffolding.
- Do not rename the `StylistA/` folder or its subfolders. The Xcode project references these paths.
- Do not modify `BodyMeasureAIWatch/` or `BodyMeasureAIWatch Watch App/` without explicit instruction. They are inactive shells.
- Do not modify `AI_DOMAIN_ROLES.md` — it's preserved domain content from the previous AGENTS.md.
- Do not call `print(...)` for logging. Use `AppLog`.
- Do not hardcode colors or spacing in views. Use `DesignSystem` tokens and `Assets.xcassets` semantic colors.
- Do not add an HTTP scheme to ATS exceptions other than `localhost`. Production traffic must be HTTPS.
- Do not change the upload JSON shape without updating the backend Zod schema and Drizzle tables in [POC_BodyMeasureAI-backend/](../POC_BodyMeasureAI-backend/).
- Do not commit `BACKEND_BASE_URL` overrides pointing at a LAN IP — that's a per-developer scheme setting.

## Definition of Done

- `xcodebuild ... build` succeeds against the iPhone 16 simulator.
- `xcodebuild ... test` passes.
- New screens are reachable through `AppCoordinator` (no orphan views).
- If wire format changed: a real upload round-trips against the local backend and lands in `scan_sessions`.
- No new `print` calls, no new hardcoded colors, no new third-party dependency managers.
- Files are placed in the right `StylistA/<Layer>/` folder per the rules above.

## Commit Conventions

Conventional Commits style. Recent history shows `feat(...)`, `fix(...)`, `chore(...)` with scoped prefixes:

```
feat(onboarding): add 10-screen pre-scan instructions walkthrough
fix: improve keypoint normalization and add error logging
chore(...)
```

Match scope to the layer or feature touched (`feat(body-capture)`, `feat(onboarding)`). One concern per commit.
