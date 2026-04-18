//
//  AppCoordinator.swift
//  BodyMeasureAI
//
//  Holds session state and navigation path for linear POC flow.
//

import AVFoundation
import Combine
import SwiftUI

/// Linear flow steps (no tab bar).
enum FlowStep: Hashable {
    case bodyCapture
    case multiAngleCapture
    case results
    case garmentCapture
    case garmentResult
    case finalResult
    case validationMode
}

@MainActor
final class AppCoordinator: ObservableObject {
    /// Binding from ContentView so path updates trigger navigation (path in ViewModel can fail to update UI).
    var navigationPathBinding: Binding<NavigationPath>?

    var bodyCaptureViewModel: BodyCaptureViewModel
    var garmentCaptureViewModel: GarmentCaptureViewModel

    @Published var bodyResult: BodyScanResult?
    @Published var garmentResult: GarmentTagModel?

    /// Status of the most recent upload to the admin backend. Observed by
    /// results screens that want to surface a "Synced" indicator.
    enum UploadStatus: Equatable {
        case idle
        case uploading
        case success(remoteId: String)
        case failure(message: String)
    }
    @Published var uploadStatus: UploadStatus = .idle
    /// Session IDs we've already pushed, so re-entering a results view doesn't
    /// double-upload on `onAppear`.
    private var uploadedSessionIds: Set<String> = []

    init() {
        self.bodyCaptureViewModel = BodyCaptureViewModel()
        self.garmentCaptureViewModel = GarmentCaptureViewModel()
    }

    private func appendToPath(_ step: FlowStep) {
        navigationPathBinding?.wrappedValue.append(step)
    }

    private func removeLastFromPath() {
        guard navigationPathBinding?.wrappedValue.isEmpty == false else { return }
        navigationPathBinding?.wrappedValue.removeLast()
    }

    private func clearPath() {
        navigationPathBinding?.wrappedValue = NavigationPath()
    }

    var userHeightCm: Double {
        get { bodyCaptureViewModel.userHeightCm }
        set { bodyCaptureViewModel.userHeightCm = newValue }
    }

    var isFemale: Bool {
        get { bodyCaptureViewModel.isFemale }
        set { bodyCaptureViewModel.isFemale = newValue }
    }

    /// Request camera permission first; only then navigate to body capture.
    func requestCameraAndStartScan() {
        bodyCaptureViewModel.resetLiveState()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            appendToPath(.bodyCapture)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.appendToPath(.bodyCapture)
                    }
                    // If denied, user can open Settings; we don’t navigate
                }
            }
        default:
            // Denied or restricted: still navigate so BodyCaptureView can show “Open Settings”
            appendToPath(.bodyCapture)
        }
    }

    func startBodyScan() {
        bodyCaptureViewModel.resetLiveState()
        appendToPath(.bodyCapture)
    }

    /// Start 3-angle body scan flow (front / side / back) without affecting existing single-angle flow.
    func startMultiAngleScan() {
        bodyCaptureViewModel.resetLiveState()
        appendToPath(.multiAngleCapture)
    }

    func bodyCaptured(result: BodyScanResult) {
        bodyResult = result
        appendToPath(.results)
    }

    func continueToGarment() {
        appendToPath(.garmentCapture)
    }

    func garmentAnalysed(result: GarmentTagModel) {
        garmentResult = result
        appendToPath(.garmentResult)
    }

    func completeScan() {
        appendToPath(.finalResult)
    }

    func openValidationMode() {
        appendToPath(.validationMode)
    }

    func newScan() {
        bodyResult = nil
        garmentResult = nil
        bodyCaptureViewModel.clearResult()
        bodyCaptureViewModel.resetLiveState()
        garmentCaptureViewModel.clearSelection()
        newScanClearsUploadState()
        clearPath()
    }

    func popLast() {
        removeLastFromPath()
    }

    func buildSession() -> ScanSessionModel? {
        guard let body = bodyResult else { return nil }
        guard let garment = garmentResult else { return nil }
        return ScanSessionModel.from(bodyResult: body, garmentResult: garment)
    }

    // MARK: - Backend upload

    func newScanClearsUploadState() {
        uploadStatus = .idle
        uploadedSessionIds.removeAll()
    }

    /// Upload the full body+garment session. Idempotent per sessionId.
    func uploadCompletedSession(_ session: ScanSessionModel) {
        guard !uploadedSessionIds.contains(session.sessionId) else { return }
        uploadedSessionIds.insert(session.sessionId)
        uploadStatus = .uploading
        Task { [weak self] in
            let result = await BackendAPIClient.upload(session: session)
            await MainActor.run {
                self?.uploadStatus = Self.mapStatus(result)
            }
        }
    }

    /// Upload just the body scan (no garment captured). Idempotent per timestamp.
    func uploadBodyOnlyIfNeeded(_ body: BodyScanResult) {
        let key = ISO8601DateFormatter().string(from: body.measurements.timestamp)
        guard !uploadedSessionIds.contains(key) else { return }
        uploadedSessionIds.insert(key)
        uploadStatus = .uploading
        Task { [weak self] in
            let result = await BackendAPIClient.upload(bodyOnly: body)
            await MainActor.run {
                self?.uploadStatus = Self.mapStatus(result)
            }
        }
    }

    private static func mapStatus(
        _ result: Result<BackendUploadResult, BackendUploadError>
    ) -> UploadStatus {
        switch result {
        case .success(let r):
            return .success(remoteId: r.remoteSessionId)
        case .failure(let err):
            return .failure(message: "\(err)")
        }
    }
}
