//
//  BodyCaptureViewModel.swift
//  BodyMeasureAI
//
//  Manages AVCaptureSession + Vision body pose pipeline. MVVM: no UI logic.
//

import AVFoundation
import Combine
import CoreImage
import Foundation
import SwiftUI
import Vision
import AudioToolbox

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
    @Published var isFrontCamera: Bool = false
    
    // MARK: - Timer State
    @Published var selectedTimer: Int = UserDefaults.standard.integer(forKey: "selectedTimer") {
        didSet {
            UserDefaults.standard.set(selectedTimer, forKey: "selectedTimer")
        }
    }
    @Published private(set) var isCountingDown: Bool = false
    @Published private(set) var countdown: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
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
    private var bufferAttemptCount: Int = 0
    private var bufferInvalidCount: Int = 0
    private var bufferConsecutiveInvalidCount: Int = 0

    /// Latest pixel buffer from camera for snapshot capture.
    private nonisolated(unsafe) var latestPixelBuffer: CVPixelBuffer?
    private let ciContext = CIContext()

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

    private static let captureDeviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    
    private var isConfiguringSession: Bool = false

    // MARK: - Setup

    func requestCameraAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            configureCaptureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraDenied = !granted
                    if granted {
                        self?.configureCaptureSessionIfNeeded()
                    }
                }
            }
        default:
            cameraDenied = true
        }
    }

    func configureCaptureSession() {
        configureCaptureSessionIfNeeded(force: true)
    }

    private func configureCaptureSessionIfNeeded(force: Bool = false) {
        let desiredPosition: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isConfiguringSession {
                return
            }
            self.isConfiguringSession = true
            defer { self.isConfiguringSession = false }
            
            if !force, self.isSessionConfigured(for: desiredPosition) {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }
            
            self._configureCaptureSession(desiredPosition: desiredPosition)
        }
    }
    
    private func isSessionConfigured(for position: AVCaptureDevice.Position) -> Bool {
        guard session.outputs.isEmpty == false else { return false }
        guard let input = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else { return false }
        return input.device.position == position
    }
    
    private func _configureCaptureSession(desiredPosition: AVCaptureDevice.Position) {
        Log.debug("_configureCaptureSession called", context: ["sessionRunning": session.isRunning, "isFrontCamera": (desiredPosition == .front)])
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.captureDeviceTypes,
            mediaType: .video,
            position: desiredPosition
        )
        guard let camera = discovery.devices.first else {
            Log.error("Failed to get camera", context: [
                "position": desiredPosition.rawValue,
                "availableCameras": AVCaptureDevice.DiscoverySession(deviceTypes: Self.captureDeviceTypes, mediaType: .video, position: .unspecified).devices.map { $0.localizedName }
            ])
            return
        }
        
        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: camera)
        } catch {
            Log.error("Error creating device input", context: ["error": error.localizedDescription])
            return
        }
        
        // Swapping camera inputs can temporarily pause the running pipeline.
        // Stop + restart makes the change deterministic and avoids frozen previews.
        let wasRunning = session.isRunning
        if wasRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            Log.debug("_configureCaptureSession finished")
            
            if !session.isRunning, session.inputs.isEmpty == false {
                session.startRunning()
            }
        }

        // We only need to change the input device, not the output.
        // This makes switching much faster.
        let currentInputs = session.inputs
        for input in currentInputs {
            Log.debug("Removing input: \(input)")
            session.removeInput(input)
        }

        Log.debug("Requesting camera", context: ["position": desiredPosition.rawValue])
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            Log.debug("Successfully added input", context: ["camera": camera.localizedName])
        } else {
            for input in currentInputs {
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            }
            Log.error("Cannot add input to session")
            return
        }

        // If output doesn't exist, create and add it.
        if session.outputs.isEmpty {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: visionQueue)
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                Log.debug("Successfully added video output")
            } else {
                Log.error("Cannot add output to session")
            }
        }

        // Ensure portrait orientation and mirroring are set correctly on the existing output
        if let output = session.outputs.first as? AVCaptureVideoDataOutput,
           let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (desiredPosition == .front)
                Log.debug("Set video mirrored", context: ["mirrored": connection.isVideoMirrored])
            }
        }
    }

    func toggleCamera() {
        Log.info("Toggle camera tapped", context: ["isFrontCamera": isFrontCamera])
        
        let targetIsFront = !isFrontCamera
        let targetPosition: AVCaptureDevice.Position = targetIsFront ? .front : .back
        let hasTargetCamera = !AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.captureDeviceTypes,
            mediaType: .video,
            position: targetPosition
        ).devices.isEmpty
        
        guard hasTargetCamera else {
            Log.warn("Toggle aborted, no camera found", context: ["targetPosition": targetPosition.rawValue])
            return
        }
        
        isFrontCamera = targetIsFront
        Log.info("Camera toggled", context: ["isFrontCamera": isFrontCamera])
        configureCaptureSessionIfNeeded(force: true)
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
        cancelCountdown()
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // Timer reference for cancellation
    private var countdownTimer: Timer?

    /// Capture button tapped: Start buffering multi-frame measurements or timer
    func capture() {
        if isCountingDown {
            cancelCountdown()
            return
        }
        
        guard canCapture, !isBuffering else { return }
        
        if selectedTimer > 0 {
            startCountdown()
        } else {
            AudioServicesPlaySystemSound(1108) // camera shutter
            startBufferingCapture()
        }
    }
    
    private func startCountdown() {
        isCountingDown = true
        countdown = selectedTimer
        
        // Initial tick
        AudioServicesPlaySystemSound(1103) // tick
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                self.countdown -= 1
                
                if self.countdown > 0 {
                    AudioServicesPlaySystemSound(1103) // tick
                } else {
                    timer.invalidate()
                    self.isCountingDown = false
                    AudioServicesPlaySystemSound(1108) // camera shutter
                    
                    // Check if we can actually capture now
                    if self.isBodyDetected && self.isStable && self.currentConfidence >= self.minConfidenceToEnableCapture {
                        self.startBufferingCapture()
                    } else {
                        self.bodyNotInFrameMessage = "Capture failed. Body not fully visible."
                    }
                }
            }
        }
    }
    
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountingDown = false
        countdown = 0
    }

    private func startBufferingCapture() {
        isBuffering = true
        measurementBuffer.removeAll()
        bufferProgress = 0.0
        bufferAttemptCount = 0
        bufferInvalidCount = 0
        bufferConsecutiveInvalidCount = 0
        bodyNotInFrameMessage = nil
    }
    
    // Minimum physiological circumference thresholds (cm).
    // Frames below these are rejected (e.g. side-view where left/right keypoints overlap).
    private static let minShoulderCircumferenceCm: Double = 30.0
    private static let minHipCircumferenceCm: Double = 40.0

    /// Process a new frame for buffering
    private func processFrameForBuffer(_ observation: VNHumanBodyPoseObservation, confidence: Double) {
        guard isBuffering else { return }

        bufferAttemptCount += 1
        let normalizer = KeypointNormalizer(userHeightCm: userHeightCm)
        if let model = normalizer.normalize(observation, overallConfidence: confidence) {
            // Reject physiologically impossible measurements.
            // In side view, left/right keypoints overlap in X, producing near-zero widths.
            guard model.m1ShoulderCircumferenceCm >= Self.minShoulderCircumferenceCm,
                  model.m2HipCircumferenceCm >= Self.minHipCircumferenceCm else {
                bufferInvalidCount += 1
                bufferConsecutiveInvalidCount += 1
                checkBufferBailout(measurementsRejected: true)
                return
            }

            measurementBuffer.append(model)
            bufferProgress = Double(measurementBuffer.count) / Double(requiredBufferCount)
            bufferConsecutiveInvalidCount = 0

            if measurementBuffer.count >= requiredBufferCount {
                finalizeCapture()
            }
        } else {
            bufferInvalidCount += 1
            bufferConsecutiveInvalidCount += 1
            checkBufferBailout(measurementsRejected: false)
        }
    }

    /// Check whether buffering should be abandoned due to too many failures.
    private func checkBufferBailout(measurementsRejected: Bool) {
        let maxAttempts = requiredBufferCount + 25
        let maxConsecutiveInvalid = 8
        if bufferAttemptCount >= maxAttempts || bufferConsecutiveInvalidCount >= maxConsecutiveInvalid {
            isBuffering = false
            bufferProgress = 0.0
            if measurementsRejected {
                bodyNotInFrameMessage = "Measurements out of range. Please face the camera directly with your full body visible."
            } else {
                bodyNotInFrameMessage = "Please stand still and ensure your full body is visible."
            }
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

        var result = BodyScanResult(
            measurements: medianModel,
            positiveMessage: output.positiveMessage,
            verticalType: output.verticalType,
            isPetite: output.isPetite,
            userHeightCm: userHeightCm,
            gender: isFemale ? "female" : "male"
        )
        
        Log.info("Capture finalized (median of \(measurementBuffer.count) frames)", context: [
            "confidence": medianModel.captureConfidence,
            "m1ShoulderCm": medianModel.m1ShoulderCircumferenceCm,
            "m2HipCm": medianModel.m2HipCircumferenceCm,
            "m3WaistCm": medianModel.m3WaistCircumferenceCm,
            "v1TorsoCm": medianModel.v1TorsoHeightCm,
            "v2LegCm": medianModel.v2LegLengthCm,
            "waistProminence": medianModel.waistProminenceScore
        ])

        // Save snapshot from latest camera frame
        if let buffer = latestPixelBuffer {
            let ciImage = CIImage(cvPixelBuffer: buffer)
            if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                let snapshot = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                if let filename = ImageStorageService.shared.saveImageLocally(image: snapshot, prefix: "body") {
                    result.imageLocalFilename = filename
                    Task.detached {
                        if let fileId = await ImageStorageService.shared.uploadToCloud(filename: filename) {
                            await MainActor.run {
                                result.imageRemoteFileId = fileId
                            }
                        }
                    }
                }
            }
        }

        capturedResult = result
    }

    /// Clear result so user can "Scan Again".
    func clearResult() {
        capturedResult = nil
    }

    /// Reset all live-detection state so starting a new scan does not show
    /// previous frame's skeleton/confidence.
    func resetLiveState() {
        cancelCountdown()
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
    var canCapture: Bool {
        if isCountingDown { return false }
        return isBodyDetected && isStable && currentConfidence >= minConfidenceToEnableCapture
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
        self.latestPixelBuffer = pixelBuffer
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
                    Log.debug("Live pose", context: ["confidence": "\(percent)%", "isStable": self.isStable, "canCapture": canNowCapture])
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
