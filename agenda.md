# 📅 Project Agenda & Tasks

This document tracks the ongoing development, outstanding tasks, and future features for the **POC Body Measure AI** iOS application.

## 📌 Phase 1: Core AI & Vision Integration (Current)
- [ ] Refine `BodyClassificationEngine.swift` for more accurate body proportion analysis.
- [ ] Improve `KeypointNormalizer.swift` to handle different camera angles and distances reliably.
- [ ] Implement robust error handling in `BodyCaptureViewModel.swift` if a scan fails or lighting is poor.
- [ ] Tune `GarmentClassifierService.swift` ML model (if applicable) for better accuracy on complex clothing patterns.
- [ ] Refine `GarmentColorExtractor.swift` to better distinguish primary/secondary colors under varying light conditions.

## 🎨 Phase 2: UI/UX & Flow Enhancements
- [ ] Polish `OnboardingView.swift` to guide users effectively on how to position their phone and body.
- [ ] Enhance feedback in `MultiAngleBodyScanView.swift` (e.g., haptic feedback, audio cues when angles are captured).
- [ ] Update `DesignSystem.swift` to ensure consistent theming across light/dark modes.
- [ ] Improve `ValidationModeView.swift` for debugging and testing edge cases.

## 💾 Phase 3: Data Management & Export
- [ ] Finalize `JSONExportService.swift` schema for compatibility with the backend / styling engine.
- [ ] Persist `ScanSessionModel.swift` data locally (CoreData or SwiftData) for offline use.
- [ ] Handle privacy and permissions gracefully (Camera access, photo library access).

## 🚀 Phase 4: Quality Assurance & Launch
- [ ] Write Unit Tests for `BodyClassificationEngine` and `KeypointNormalizer`.
- [ ] Write UI Tests for the critical path (`Onboarding` -> `Body Scan` -> `Garment Scan` -> `Results`).
- [ ] Test on multiple iOS devices (iPhone 13, 14, 15, Pro vs Non-Pro for LiDAR/Camera differences).
- [ ] Setup Fastlane for automated builds and TestFlight deployment.

---

### 📝 Notes
*Add any daily updates or development notes below.*

- **Date:** YYYY-MM-DD
  - *Note:* ...