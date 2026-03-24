# Camera Timer Feature Plan

## Summary
Design and implement a configurable delay timer (0s, 2s, 3s, 5s) for the iOS camera with native iOS audio feedback and robust accessibility/single-user optimizations.

## Current State Analysis
- The iOS app (`BodyMeasureAI`) currently handles camera sessions and body tracking within `BodyCaptureViewModel.swift` and `BodyCaptureView.swift`.
- Capture is immediate upon pressing the capture button (subject to detection confidence).
- No timer functionality or audio countdown exists.

## Proposed Changes

### 1. iPhone Camera Enhancements (`BodyCaptureViewModel.swift` & `BodyCaptureView.swift`)
- **Timer Logic**: Introduce a configurable delay timer (Options: 0s, 2s, 3s, 5s).
- **Settings Persistence**: Use `UserDefaults` to persist the user's timer preference.
- **Audio Cues**: Integrate `AudioServicesPlaySystemSound` to play authentic tick (e.g., ID 1103/1206) and tock/capture sounds during the countdown phase.
- **Visual Cues (Single User)**: Add a large, high-contrast, animated countdown text overlay on `BodyCaptureView` to help the user position themselves.

### 2. Testing & Documentation
- **`CameraTimerTests.swift`**: Develop unit tests verifying timer state logic and countdown accuracy.
- **`docs/CameraTimer.md`**: Comprehensive documentation covering the technical architecture, user flow diagrams, and error handling behaviors.

## Assumptions & Decisions
- **Audio Feedback**: Will utilize built-in iOS system sounds for the tick-tock countdown to match the native camera feel without requiring custom assets.
- **Settings Persistence**: `UserDefaults` will be used for the iPhone to store the timer preference.

## Verification Steps
1. Build and run the iPhone target in the simulator or on a physical device.
2. Toggle the timer on the iPhone; verify the timer preference updates.
3. Tap Capture on the iPhone; verify the visual countdown begins and the system tick-tock sounds play.
4. Run `CameraTimerTests.swift` to ensure logic correctness.