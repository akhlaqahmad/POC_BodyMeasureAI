//
//  BodyCaptureViewModel.swift
//  BodyMeasureAI
//
//  Manages AVCaptureSession + Vision body pose pipeline. MVVM: no UI logic.
//

import AVFoundation
import Combine
import Foundation
import SwiftUI
import Vision
import os

@MainActor
final class BodyCaptureViewModel: NSObject, ObservableObject {

    // MARK: - Published state for View

    @Published private(set) var isBodyDetected: Bool = false
    @Published private(set) var currentConfidence: Double = 0
    @Published private(set) var capturedResult: BodyScanResult?
    /// Current pose observation for skeleton overlay (normalized 0–1). Nil when no body.
    @Published private(set) var currentObservation: VNHumanBodyPoseObservation?
    @Published var cameraDenied = false
    @Published private(set) var isStable: Bool = false
    /// Shown when body is detected but ankles are out of frame (full body must be visible).
    @Published var bodyNotInFrameMessage: String?
    /// Auto-capture countdown remaining in whole seconds, or nil when not counting down.
    @Published private(set) var autoCaptureCountdown: Int? = nil

    private var stableFrameCount: Int = 0
    /// For POC: 6 frames so stability is achievable but not too jumpy.
    private static let stableFramesRequired = 6
    /// Need more stable frames before auto-capture fires than the UI button needs.
    private static let stableFramesRequiredForAuto = 10
    /// Build stability when confidence >= 0.45 so 48–49% frames still count (capture still needs >= 0.5).
    private let minConfidenceForStability: Double = 0.45
    /// Frames of sub-threshold confidence tolerated before we reset stability
    /// (a 200 ms grace window at ~15 fps post-throttle).
    private static let badFrameGraceFrames = 3
    private var badFramesSinceStable: Int = 0
    /// Countdown task so we can cancel if the body is lost mid-countdown.
    private var autoCaptureTask: Task<Void, Never>? = nil
    // Debug: throttle logging so console doesn't flicker every frame.
    private var lastLoggedPercent: Int = -1
    private var lastLoggedCanCapture: Bool = false
    private var lastLogTime: CFAbsoluteTime = 0

    // MARK: - User inputs (set from OnboardingView)

    @Published var userHeightCm: Double = 170
    @Published var gender: Gender = .female

    // MARK: - Capture session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "BodyCapture.session")
    private let visionQueue = DispatchQueue(label: "BodyCapture.vision")
    private static let processEveryNthFrame = 5
    /// POC: enable capture when confidence >= 0.50.
    private let minConfidenceToEnableCapture: Double = 0.5

    /// Default to the front (selfie) camera: users typically scan themselves.
    /// Flip button lets an assistant use the back camera.
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .front

    private let classificationEngine = BodyClassificationEngine()

    // MARK: - Setup

    func requestCameraAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraDenied = !granted
                    if granted {
                        self?.configureCaptureSession()
                    }
                }
            }
        default:
            cameraDenied = true
        }
    }

    func configureCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self._configureCaptureSession()
            // Small delay ensures commitConfiguration has finished before running.
            Thread.sleep(forTimeInterval: 0.1)
            if !self.session.isRunning {
                self.session.startRunning()
                AppLog.capture.info("capture session started — preset=hd1920x1080")
            } else {
                AppLog.capture.debug("capture session already running — skipping startRunning")
            }
        }
    }

    private func _configureCaptureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1920x1080
        applyCameraInputAndOutput()
    }

    /// Adds the device input and video-data output for `cameraPosition`.
    /// Assumes caller has bracketed beginConfiguration / commitConfiguration.
    private func applyCameraInputAndOutput() {
        // Tear down any prior inputs/outputs so flipping doesn't stack them.
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: cameraPosition
        ) else {
            Task { @MainActor in cameraDenied = true }
            return
        }
        guard let input = try? AVCaptureDeviceInput(device: camera) else { return }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: visionQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            if let connection = output.connection(with: .video) {
                // Portrait orientation so Vision keypoints align with preview.
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                // Mirror the front-camera feed so the user sees themselves
                // naturally. Vision operates on the buffer (already mirrored
                // at the buffer level when this flag is true), and the
                // SkeletonOverlayView draws from normalized coords — it stays
                // consistent with the mirrored preview.
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = cameraPosition == .front
                }
            }
        }
    }

    /// Flip between front and back cameras. Resets live state so the skeleton
    /// and confidence don't carry over from the previous feed.
    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == .front ? .back : .front
        cameraPosition = newPosition
        resetLiveState()
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let wasRunning = self.session.isRunning
            if wasRunning { self.session.stopRunning() }
            self.session.beginConfiguration()
            self.applyCameraInputAndOutput()
            self.session.commitConfiguration()
            if wasRunning { self.session.startRunning() }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning && !self.session.inputs.isEmpty {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                AppLog.capture.info("capture session stopped")
            }
        }
    }

    /// Capture button tapped: run normalizer + classification, publish result.
    func capture() {
        // Only allow capture when UI says we can capture (green button).
        guard canCapture, let observation = currentObservation else {
            AppLog.capture.error(
                "capture() no-op: canCapture=\(self.canCapture, privacy: .public) hasObservation=\(self.currentObservation != nil, privacy: .public)"
            )
            return
        }

        let normalizer = KeypointNormalizer(userHeightCm: userHeightCm, gender: gender)
        guard let model = normalizer.normalize(observation, overallConfidence: currentConfidence) else {
            AppLog.capture.error(
                "capture() no-op: normalizer.normalize returned nil — required joints may be missing for this angle"
            )
            return
        }

        let output = classificationEngine.classify(
            m1: model.m1ShoulderCircumferenceCm,
            m2: model.m2HipCircumferenceCm,
            m3: model.m3WaistCircumferenceCm,
            v1: model.v1TorsoHeightCm,
            v2: model.v2LegLengthCm,
            userHeightCm: userHeightCm,
            gender: gender,
            waistProminenceScore: model.waistProminenceScore
        )

        let result = BodyScanResult(
            measurements: model,
            positiveMessage: output.positiveMessage,
            verticalType: output.verticalType,
            isPetite: output.isPetite,
            userHeightCm: userHeightCm,
            gender: gender.rawValue
        )
        
        AppLog.capture.info(
            """
            captured: conf=\(self.currentConfidence, format: .fixed(precision: 2), privacy: .public) \
            M1=\(model.m1ShoulderCircumferenceCm, format: .fixed(precision: 1), privacy: .public) \
            M2=\(model.m2HipCircumferenceCm, format: .fixed(precision: 1), privacy: .public) \
            M3=\(model.m3WaistCircumferenceCm, format: .fixed(precision: 1), privacy: .public) \
            V1=\(model.v1TorsoHeightCm, format: .fixed(precision: 1), privacy: .public) \
            V2=\(model.v2LegLengthCm, format: .fixed(precision: 1), privacy: .public) \
            prominence=\(model.waistProminenceScore, format: .fixed(precision: 2), privacy: .public)
            """
        )

        capturedResult = result
    }

    /// Clear result so user can "Scan Again".
    func clearResult() {
        capturedResult = nil
    }

    /// Reset all live-detection state so starting a new scan does not show
    /// previous frame's skeleton/confidence.
    func resetLiveState() {
        AppLog.capture.info("resetLiveState: clearing pose/stability state for next capture")
        currentObservation = nil
        isBodyDetected = false
        currentConfidence = 0
        stableFrameCount = 0
        badFramesSinceStable = 0
        isStable = false
        bodyNotInFrameMessage = nil
        lastLoggedPercent = -1
        lastLoggedCanCapture = false
        lastLogTime = 0
        cancelAutoCapture()
    }

    // MARK: - Auto-capture countdown

    /// Begin a 3-second countdown that calls `capture()` at zero. Safe to call
    /// repeatedly — no-op if a countdown is already running.
    func startAutoCaptureCountdown(onCapture: @escaping (BodyScanResult) -> Void) {
        guard autoCaptureTask == nil, canCapture else {
            AppLog.capture.debug("startAutoCaptureCountdown: skipped (taskRunning=\(self.autoCaptureTask != nil, privacy: .public) canCapture=\(self.canCapture, privacy: .public))")
            return
        }
        AppLog.capture.info("startAutoCaptureCountdown: 3…2…1")
        autoCaptureCountdown = 3
        autoCaptureTask = Task { [weak self] in
            guard let self = self else { return }
            for n in [3, 2, 1] {
                self.autoCaptureCountdown = n
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled {
                    AppLog.capture.debug("auto-capture: task cancelled mid-countdown")
                    return
                }
                // Abort if the scan state decayed during the tick.
                if !self.canCapture || !self.isStable {
                    AppLog.capture.debug("auto-capture: aborted — canCapture=\(self.canCapture, privacy: .public) isStable=\(self.isStable, privacy: .public)")
                    self.autoCaptureCountdown = nil
                    self.autoCaptureTask = nil
                    return
                }
            }
            self.autoCaptureCountdown = nil
            self.capture()
            if let result = self.capturedResult {
                onCapture(result)
            } else {
                AppLog.capture.error(
                    "auto-capture: countdown done but capture() produced no result — flow will not advance"
                )
            }
            self.autoCaptureTask = nil
        }
    }

    /// Cancel an in-flight countdown (called when body moves out of frame or
    /// view disappears). Safe to call when no countdown is running.
    func cancelAutoCapture() {
        autoCaptureTask?.cancel()
        autoCaptureTask = nil
        autoCaptureCountdown = nil
    }

    /// Whether the capture button should be enabled.
    /// For POC we do not require isStable so the button can turn green as soon
    /// as detection confidence passes the threshold.
    var canCapture: Bool {
        isBodyDetected && currentConfidence >= minConfidenceToEnableCapture
    }

    /// Whether the pose has been stable long enough to trigger auto-capture.
    /// Stricter than `canCapture` to avoid snapping the photo on a brief peak.
    var isReadyForAutoCapture: Bool {
        canCapture && isStable && stableFrameCount >= Self.stableFramesRequiredForAuto
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BodyCaptureViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Used from nonisolated delegate to throttle to every Nth frame without touching MainActor.
    private static let frameCounter = FrameCounter()
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        Self.frameCounter.increment()
        if Self.frameCounter.value % Self.processEveryNthFrame != 0 { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectHumanBodyPoseRequest()
        request.revision = VNDetectHumanBodyPoseRequestRevision1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first as? VNHumanBodyPoseObservation else {
            Task { @MainActor in
                self.currentObservation = nil
                self.isBodyDetected = false
                self.currentConfidence = 0
                self.stableFrameCount = 0
                self.isStable = false
                self.bodyNotInFrameMessage = nil
            }
            return
        }

        Task { @MainActor in
            let confidence = self.averageKeypointConfidence(observation)
            self.currentObservation = observation
            self.currentConfidence = confidence

            // Looser ankle logic: at least one ankle with small confidence is enough
            // for detection; only show "step back" if neither ankle is seen at all.
            let leftAnkleConf = (try? observation.recognizedPoint(.leftAnkle))?.confidence ?? 0
            let rightAnkleConf = (try? observation.recognizedPoint(.rightAnkle))?.confidence ?? 0
            let anklesVisible = leftAnkleConf > 0.15 || rightAnkleConf > 0.15

            if !anklesVisible {
                self.isBodyDetected = false
                self.stableFrameCount = 0
                self.isStable = false
                if leftAnkleConf < 0.1 && rightAnkleConf < 0.1 {
                    self.bodyNotInFrameMessage = "Step back — full body including feet must be visible"
                } else {
                    self.bodyNotInFrameMessage = nil
                }
                return
            }
            self.bodyNotInFrameMessage = nil
            self.isBodyDetected = true

            // Build stability when confidence >= 0.45. Once stable, tolerate
            // up to `badFrameGraceFrames` sub-threshold frames (~200 ms at
            // 15 fps post-throttle) before resetting — this stops the UI from
            // calling "stand still" on single-frame flickers when the user is
            // actually motionless.
            if confidence >= self.minConfidenceForStability {
                self.badFramesSinceStable = 0
                self.stableFrameCount = min(
                    self.stableFrameCount + 1,
                    Self.stableFramesRequiredForAuto
                )
                if self.stableFrameCount >= Self.stableFramesRequired {
                    self.isStable = true
                }
            } else {
                self.badFramesSinceStable += 1
                if self.badFramesSinceStable >= Self.badFrameGraceFrames {
                    self.stableFrameCount = 0
                    self.isStable = false
                    self.cancelAutoCapture()
                }
            }

            // Throttled debug: log when canCapture changes or at most once per second.
            let percent = Int(confidence * 100)
            let canNowCapture = self.canCapture
            let now = CFAbsoluteTimeGetCurrent()
            let canCaptureChanged = canNowCapture != self.lastLoggedCanCapture
            let throttleInterval = 1.0
            if canCaptureChanged || (now - self.lastLogTime >= throttleInterval) {
                if canCaptureChanged || percent != self.lastLoggedPercent {
                    self.lastLoggedPercent = percent
                    self.lastLoggedCanCapture = canNowCapture
                    self.lastLogTime = now
                    AppLog.capture.debug("pose conf=\(percent)% stable=\(self.isStable, privacy: .public) canCapture=\(canNowCapture, privacy: .public)")
                }
            }
        }
    }

    private func averageKeypointConfidence(_ observation: VNHumanBodyPoseObservation) -> Double {
        // Only use a small set of stable joints for the confidence score.
        let keyJoints: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .leftShoulder,
            .rightShoulder,
            .leftHip,
            .rightHip,
            .leftKnee,
            .rightKnee
        ]
        var sum: Float = 0
        var count = 0
        for joint in keyJoints {
            if let pt = try? observation.recognizedPoint(joint) {
                sum += pt.confidence
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        return Double(sum) / Double(count)
    }
}

/// Thread-local counter for throttling frame processing in the delegate (nonisolated).
private final class FrameCounter: @unchecked Sendable {
    var value = 0
    func increment() { value += 1 }
}
