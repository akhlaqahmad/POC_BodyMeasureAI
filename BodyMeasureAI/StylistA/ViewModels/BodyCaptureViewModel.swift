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
    
    /// Multi-frame buffer state
    @Published private(set) var isBuffering: Bool = false
    @Published private(set) var bufferProgress: Double = 0.0

    private var stableFrameCount: Int = 0
    /// For POC: 6 frames so stability is achievable but not too jumpy.
    private static let stableFramesRequired = 6
    /// Build stability when confidence >= 0.45 so 48–49% frames still count (capture still needs >= 0.5).
    private let minConfidenceForStability: Double = 0.45
    // Debug: throttle logging so console doesn't flicker every frame.
    private var lastLoggedPercent: Int = -1
    private var lastLoggedCanCapture: Bool = false
    private var lastLogTime: CFAbsoluteTime = 0
    
    // Multi-frame measurement buffer
    private var measurementBuffer: [BodyProportionModel] = []
    private let requiredBufferCount = 10

    // MARK: - User inputs (set from OnboardingView)

    @Published var userHeightCm: Double = 170
    @Published var isFemale: Bool = true

    // MARK: - Capture session

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "BodyCapture.session")
    private let visionQueue = DispatchQueue(label: "BodyCapture.vision")
    private static let processEveryNthFrame = 5
    /// POC: enable capture when confidence >= 0.50.
    private let minConfidenceToEnableCapture: Double = 0.5

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
            }
        }
    }

    private func _configureCaptureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1920x1080
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
            // Ensure portrait orientation so Vision keypoints align with preview.
            if let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
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
            self?.session.stopRunning()
        }
    }

    /// Capture button tapped: Start buffering multi-frame measurements
    func capture() {
        // Only allow capture when UI says we can capture (green button)
        guard canCapture, !isBuffering else { return }
        
        isBuffering = true
        measurementBuffer.removeAll()
        bufferProgress = 0.0
    }
    
    /// Process a new frame for buffering
    private func processFrameForBuffer(_ observation: VNHumanBodyPoseObservation, confidence: Double) {
        guard isBuffering else { return }
        
        let normalizer = KeypointNormalizer(userHeightCm: userHeightCm)
        if let model = normalizer.normalize(observation, overallConfidence: confidence) {
            measurementBuffer.append(model)
            bufferProgress = Double(measurementBuffer.count) / Double(requiredBufferCount)
            
            if measurementBuffer.count >= requiredBufferCount {
                finalizeCapture()
            }
        } else {
            // Frame invalid (e.g. occlusion), cancel buffering
            isBuffering = false
            bufferProgress = 0.0
            bodyNotInFrameMessage = "Please stand still and ensure your full body is visible."
        }
    }
    
    /// Calculate medians and finalize capture
    private func finalizeCapture() {
        isBuffering = false
        bufferProgress = 0.0
        
        guard !measurementBuffer.isEmpty else { return }
        
        // Calculate medians
        let m1s = measurementBuffer.map { $0.m1ShoulderCircumferenceCm }.sorted()
        let m2s = measurementBuffer.map { $0.m2HipCircumferenceCm }.sorted()
        let m3s = measurementBuffer.map { $0.m3WaistCircumferenceCm }.sorted()
        let v1s = measurementBuffer.map { $0.v1TorsoHeightCm }.sorted()
        let v2s = measurementBuffer.map { $0.v2LegLengthCm }.sorted()
        let waistProminences = measurementBuffer.map { $0.waistProminenceScore }.sorted()
        
        let medianIndex = measurementBuffer.count / 2
        let medianModel = BodyProportionModel(
            m1ShoulderCircumferenceCm: m1s[medianIndex],
            m2HipCircumferenceCm: m2s[medianIndex],
            m3WaistCircumferenceCm: m3s[medianIndex],
            v1TorsoHeightCm: v1s[medianIndex],
            v2LegLengthCm: v2s[medianIndex],
            waistProminenceScore: waistProminences[medianIndex],
            captureConfidence: measurementBuffer.map { $0.captureConfidence }.reduce(0, +) / Double(measurementBuffer.count),
            timestamp: Date()
        )

        let output = classificationEngine.classify(
            m1: medianModel.m1ShoulderCircumferenceCm,
            m2: medianModel.m2HipCircumferenceCm,
            m3: medianModel.m3WaistCircumferenceCm,
            v1: medianModel.v1TorsoHeightCm,
            v2: medianModel.v2LegLengthCm,
            userHeightCm: userHeightCm,
            isFemale: isFemale,
            waistProminenceScore: medianModel.waistProminenceScore
        )

        let result = BodyScanResult(
            measurements: medianModel,
            positiveMessage: output.positiveMessage,
            verticalType: output.verticalType,
            isPetite: output.isPetite,
            userHeightCm: userHeightCm,
            gender: isFemale ? "female" : "male"
        )
        
        // Debug logging so you can see everything in the Xcode console.
        print("=== BodyCaptureViewModel.capture (Averaged) ===")
        print("Average Confidence:", medianModel.captureConfidence)
        print("Median M1 Shoulder Circumference (cm):", medianModel.m1ShoulderCircumferenceCm)
        print("Median M2 Hip Circumference (cm):", medianModel.m2HipCircumferenceCm)
        print("Median M3 Waist Circumference (cm):", medianModel.m3WaistCircumferenceCm)
        print("Median V1 Torso Height (cm):", medianModel.v1TorsoHeightCm)
        print("Median V2 Leg Length (cm):", medianModel.v2LegLengthCm)
        print("Median Waist Prominence Score:", medianModel.waistProminenceScore)

        capturedResult = result
    }

    /// Clear result so user can "Scan Again".
    func clearResult() {
        capturedResult = nil
    }

    /// Reset all live-detection state so starting a new scan does not show
    /// previous frame's skeleton/confidence.
    func resetLiveState() {
        currentObservation = nil
        isBodyDetected = false
        currentConfidence = 0
        stableFrameCount = 0
        isStable = false
        bodyNotInFrameMessage = nil
        lastLoggedPercent = -1
        lastLoggedCanCapture = false
        lastLogTime = 0
        isBuffering = false
        bufferProgress = 0.0
        measurementBuffer.removeAll()
    }

    /// Whether the capture button should be enabled.
    /// For POC we do not require isStable so the button can turn green as soon
    /// as detection confidence passes the threshold.
    var canCapture: Bool {
        isBodyDetected && currentConfidence >= minConfidenceToEnableCapture
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
                
                // Cancel capture if we lose the body
                if self.isBuffering {
                    self.isBuffering = false
                    self.bufferProgress = 0.0
                    self.bodyNotInFrameMessage = "Capture interrupted. Please keep your body in frame."
                }
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
                
                if self.isBuffering {
                    self.isBuffering = false
                    self.bufferProgress = 0.0
                    self.bodyNotInFrameMessage = "Capture interrupted. Please keep your body in frame."
                }
                return
            }
            self.bodyNotInFrameMessage = nil
            self.isBodyDetected = true
            
            // If we are currently capturing, push this frame to the buffer
            if self.isBuffering {
                self.processFrameForBuffer(observation, confidence: confidence)
            }

            // Build stability when confidence >= 0.45 so 48–49% counts; one bad frame only decrements.
            if confidence >= self.minConfidenceForStability {
                if !self.isStable {
                    self.stableFrameCount = min(self.stableFrameCount + 1, Self.stableFramesRequired)
                    if self.stableFrameCount >= Self.stableFramesRequired {
                        self.isStable = true
                    }
                }
            } else if !self.isStable {
                self.stableFrameCount = max(0, self.stableFrameCount - 1)
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
                    print("Live pose · confidence=\(percent)% · isStable=\(self.isStable) · canCapture=\(canNowCapture)")
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
