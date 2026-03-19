# Comprehensive Improvement Plan: Body Scanning Logic

## 1. Overview & Current State Analysis
The current body scanning implementation uses Apple's Vision framework (`VNHumanBodyPoseObservation`) to detect human body keypoints. It then normalizes these keypoints into real-world centimeters using the user's provided height (`userHeightCm`) via `KeypointNormalizer.swift`. Finally, it classifies the body shape (Hourglass, Rectangle, etc.) using fixed thresholds in `BodyClassificationEngine.swift`.

### **Strengths:**
- Completely on-device (privacy-first).
- Smart use of Ramanujan’s elliptical circumference approximation to derive 3D measurements from 2D keypoints.
- Adheres strictly to the "positive messaging" rule for UI output instead of raw shape labels.

### **Current Weaknesses & Failure Points:**
1. **Single-Frame Dependency:** The capture relies on a single frame the moment the user taps "Capture". If the user is moving slightly or lighting shifts for that exact millisecond, the measurements will be highly inaccurate.
2. **Keypoint Confidence Threshold:** The `minKeypointConfidence` is set very low (`0.2`). This makes it prone to hallucinating keypoints in loose clothing or bad lighting.
3. **Occlusion Handling:** If ankles or hips are missing, the normalizer falls back to knees or a single ankle, which heavily skews the scale factor, ruining all downstream calculations (M1, M2, M3, V1, V2).
4. **No Front/Side Validation:** The rules mention that M2 (Hip Width) ideally needs a side view or depth map, but currently, it relies entirely on a front-facing 2D estimation.
5. **Waist Detection Flaw:** The current M3 calculation relies on a generic `0.85 * M2` fallback if the root node is unclear, which defeats the purpose of precise waist measurement.

---

## 2. Refactoring & Improvement Steps

### Step 1: Multi-Frame Averaging (Stability Pipeline)
Instead of capturing a single frame, the `BodyCaptureViewModel` should collect a buffer of "valid" frames and average the measurements.
- **Action:** Introduce a `MeasurementBuffer`. When `canCapture` is true and the user taps capture, record 10 valid frames over ~1-2 seconds.
- **Action:** Calculate the median (to eliminate outliers) of M1, M2, M3, V1, and V2 across those 10 frames.

### Step 2: Strict Validation & Fallback Mechanisms
We must ensure the user is standing perfectly and fully visible.
- **Action:** Increase `minKeypointConfidence` in `KeypointNormalizer.swift` from `0.2` to `0.5` minimum for critical joints (Shoulders, Hips, Ankles).
- **Action:** Add a `ValidationState` enum to `BodyCaptureViewModel`:
  - `.tooClose` (Head or ankles too close to screen edges).
  - `.occluded` (Critical joints missing).
  - `.poorLighting` (Overall confidence < 0.5).
  - `.ready` (All joints visible and stable).
- **Action:** If the user cannot get a valid read after 10 seconds, provide a manual input fallback screen ("We couldn't scan you perfectly, please input your waist/hip measurements").

### Step 3: Alignment with Measurement Rules Document
The logic must strictly map to the logic in `Body garment measurement rules (1) 32057f6befeb806cbef2f5d93d792d66.md`.

- **Action in `BodyClassificationEngine.swift` (Men):** Update the threshold for Men's Shoulder-Hip imbalance to exactly **15 cm** as specified in the rules (`M1 > M2 + 15`). The current logic has a margin, but it must be explicitly enforced and mapped to the exact supportive messages in the document.
- **Action in `BodyClassificationEngine.swift` (Men's Waist):** Update the front-heavy waist logic. If waist > hips and shoulders, trigger the specific "clean lines and cuts" message.
- **Action in `BodyClassificationEngine.swift` (Women's Petite):** Ensure the `< 1.65cm` (165cm) logic strictly appends the vertical line styling guidance.

### Step 4: Refined Waist Prominence (M3 Depth)
- **Action:** The current `computeWaistProminenceScore` uses a hacky Y-displacement of the root node. We need to prompt the user to turn 90 degrees for a "Side Profile" scan to accurately capture M2 (Hip depth) and M3 (Waist depth/front prominence) as requested in the rules ("Side view needed").

---

## 3. Comprehensive Testing Strategy

To ensure these improvements are robust, we will implement the following test suites:

### 1. Unit Tests (`KeypointNormalizerTests.swift`)
- **Mock Observation Injection:** Create mock `VNHumanBodyPoseObservation` objects with known, mathematically perfect normalized coordinates.
- **Scale Factor Test:** Assert that a 170cm user with perfectly spaced head-to-ankle coordinates outputs exactly 170cm in vertical measurements.
- **Missing Joint Test:** Assert that if both ankles are missing, the normalizer either safely falls back to knees with the correct `0.65` ratio, or correctly throws an occlusion error based on our new strict rules.

### 2. Unit Tests (`BodyClassificationEngineTests.swift`)
- **Boundary Testing:** Test exactly at the `7.62cm` (Women) and `15cm` (Men) thresholds.
- **Petite Test:** Pass `userHeightCm = 164` and ensure the petite string is appended. Pass `166` and ensure it is not.
- **Men's Imbalance Test:** Pass `M1 = 120, M2 = 100` and assert the strong upper body message is returned.

### 3. UI/Integration Tests
- **Lighting Simulation:** (If possible via mocked camera feeds) simulate a low-confidence stream and verify the UI shows "Please move to better lighting" rather than enabling the capture button.
- **Stability Test:** Verify the capture button only turns green after 6 consecutive frames of >0.5 confidence.

---

## 4. Execution Roadmap

1. **Phase 1: Math & Engine Rules Update (Immediate)**
   - Update `BodyClassificationEngine` thresholds and exact strings to match the markdown file.
2. **Phase 2: Keypoint Normalizer Strictness (Short Term)**
   - Raise confidence thresholds.
   - Remove the `M3 = M2 * 0.85` hack and force occlusion errors if waist points are missing.
3. **Phase 3: Multi-Frame Capture & UI Feedback (Medium Term)**
   - Update `BodyCaptureViewModel` to use a 10-frame median buffer.
   - Implement real-time UI alerts ("Move back", "Show ankles").
4. **Phase 4: Side-Profile Scan (Long Term)**
   - Introduce a two-step scan (Front, then Side) to accurately fulfill the "M2 side view needed" rule.