# Camera Timer Feature

## Overview
The Camera Timer Feature provides a native iOS-style delay timer for capturing body scans. This is especially useful for single-user scenarios, allowing users to position themselves correctly within the camera frame before the photo is taken.

## Features
- **Configurable Delays**: Choose between `0s`, `2s`, `3s`, and `5s`.
- **Persistent Settings**: The selected timer duration is saved to `UserDefaults` and automatically loaded on the next launch.
- **Audio Feedback**: Authentic iOS system sounds (tick-tock) play during the countdown to provide clear audio cues.
- **Visual Feedback**: A large, high-contrast countdown number overlays the camera view, ensuring it is visible from a distance.
- **Haptic Cues**: Tactile feedback is provided when cycling through timer options.

## Architecture

### `BodyCaptureViewModel`
- Manages the core timer state (`selectedTimer`, `isCountingDown`, `countdown`).
- Triggers `AudioServicesPlaySystemSound` for ticking (1103) and shutter (1108) sounds.
- Ensures the capture button is disabled while a countdown is active.

### `BodyCaptureView`
- **Timer Button**: Located next to the camera switch button. Displays the current timer setting and cycles through the options when tapped.
- **Countdown Overlay**: A large `Text` view using `.system(size: 140, weight: .bold)` is presented when `isCountingDown` is true, providing clear visual guidance.
- **Capture Button State**: Updates dynamically to reflect whether a capture is possible or if a countdown is currently in progress.

## User Flow
1. User opens the Body Scan view.
2. User taps the timer icon to cycle through the delay options (0, 2, 3, 5).
3. User steps back to ensure their full body is in the frame.
4. When the system detects the body with sufficient confidence, the capture button turns green.
5. User taps the capture button.
6. The app enters the countdown state:
   - A large number appears on screen.
   - An audible tick plays each second.
7. Upon reaching 0, a shutter sound plays, and the multi-frame buffering capture begins.
8. The result is processed and the user is navigated to the results screen.

## Testing
- `CameraTimerTests.swift` contains unit tests for verifying the persistence of the timer selection using `UserDefaults`.
