//
//  AppCoordinator.swift
//  BodyMeasureAI
//
//  Holds session state and navigation path for linear POC flow.
//

import AVFoundation
import Combine
import SwiftUI
import os

/// Linear flow steps (no tab bar).
enum FlowStep: Hashable {
    case bodyCapture
    case multiAngleCapture
    case results
    case garmentCapture
    case garmentResult
    case finalResult
    case validationMode
    case scanHistory
    case scanHistoryDetail(ScanHistoryItem.ID)
}

@MainActor
final class AppCoordinator: ObservableObject {
    /// Binding from ContentView so path updates trigger navigation (path in ViewModel can fail to update UI).
    var navigationPathBinding: Binding<NavigationPath>?

    var bodyCaptureViewModel: BodyCaptureViewModel
    var garmentCaptureViewModel: GarmentCaptureViewModel

    @Published var bodyResult: BodyScanResult?
    @Published var garmentResult: GarmentTagModel?

    /// Cached history items from the last fetch so detail pushes don't need
    /// a separate request. Populated by ScanHistoryView when it loads.
    @Published var historyItems: [ScanHistoryItem] = []

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
        AppLog.lifecycle.info("nav → \(String(describing: step), privacy: .public)")
        navigationPathBinding?.wrappedValue.append(step)
    }

    private func removeLastFromPath() {
        guard navigationPathBinding?.wrappedValue.isEmpty == false else { return }
        AppLog.lifecycle.info("nav ← pop")
        navigationPathBinding?.wrappedValue.removeLast()
    }

    private func clearPath() {
        AppLog.lifecycle.info("nav ⨯ clear")
        navigationPathBinding?.wrappedValue = NavigationPath()
    }

    var userHeightCm: Double {
        get { bodyCaptureViewModel.userHeightCm }
        set { bodyCaptureViewModel.userHeightCm = newValue }
    }

    var gender: Gender {
        get { bodyCaptureViewModel.gender }
        set { bodyCaptureViewModel.gender = newValue }
    }

    /// One-shot migration for users upgrading from a build that persisted a
    /// `isFemale` UserDefaults boolean. If the new `gender` key is unset and
    /// the legacy key exists, map it and delete the legacy key. Also persists
    /// further `gender` changes via a KVO-free observer.
    func migrateLegacyGenderIfNeeded() {
        let defaults = UserDefaults.standard
        let newKey = "gender"
        let legacyKey = "isFemale"

        if defaults.string(forKey: newKey) == nil,
           defaults.object(forKey: legacyKey) != nil {
            let isFemale = defaults.bool(forKey: legacyKey)
            let migrated: Gender = isFemale ? .female : .male
            defaults.set(migrated.rawValue, forKey: newKey)
            defaults.removeObject(forKey: legacyKey)
            bodyCaptureViewModel.gender = migrated
            AppLog.lifecycle.info(
                "migrated isFemale=\(isFemale, privacy: .public) → gender=\(migrated.rawValue, privacy: .public)"
            )
        } else if let stored = defaults.string(forKey: newKey),
                  let g = Gender(rawValue: stored) {
            bodyCaptureViewModel.gender = g
        }
    }

    /// Persist the current gender choice to UserDefaults. Call sites: after
    /// onboarding changes the picker.
    func persistGender() {
        UserDefaults.standard.set(gender.rawValue, forKey: "gender")
    }

    /// Request camera permission first; only then navigate to the guided
    /// 3-angle body capture (front / side / back).
    func requestCameraAndStartScan() {
        bodyCaptureViewModel.resetLiveState()
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            appendToPath(.multiAngleCapture)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.appendToPath(.multiAngleCapture)
                    }
                    // If denied, user can open Settings; we don’t navigate
                }
            }
        default:
            // Denied or restricted: still navigate so BodyCaptureView can show “Open Settings”
            appendToPath(.multiAngleCapture)
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

    /// Garment-first entry from onboarding. Clears any stale garment state so
    /// the capture screen opens fresh without a prior preview.
    func startGarmentScan() {
        garmentCaptureViewModel.clearSelection()
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

    func openScanHistory() {
        appendToPath(.scanHistory)
    }

    func openScanHistoryDetail(_ item: ScanHistoryItem) {
        // Ensure the item is cached so the destination view can resolve it.
        if !historyItems.contains(where: { $0.id == item.id }) {
            historyItems.append(item)
        }
        appendToPath(.scanHistoryDetail(item.id))
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
        guard !uploadedSessionIds.contains(session.sessionId) else {
            AppLog.upload.debug("skip duplicate upload sessionId=\(session.sessionId, privacy: .public)")
            return
        }
        uploadedSessionIds.insert(session.sessionId)
        setUploadStatus(.uploading)
        Task { [weak self] in
            let result = await BackendAPIClient.upload(session: session)
            await MainActor.run {
                self?.setUploadStatus(Self.mapStatus(result))
            }
        }
    }

    /// Upload just the body scan (no garment captured). Idempotent per timestamp.
    func uploadBodyOnlyIfNeeded(_ body: BodyScanResult) {
        let key = ISO8601DateFormatter().string(from: body.measurements.timestamp)
        guard !uploadedSessionIds.contains(key) else {
            AppLog.upload.debug("skip duplicate body-only upload key=\(key, privacy: .public)")
            return
        }
        uploadedSessionIds.insert(key)
        setUploadStatus(.uploading)
        Task { [weak self] in
            let result = await BackendAPIClient.upload(bodyOnly: body)
            await MainActor.run {
                self?.setUploadStatus(Self.mapStatus(result))
            }
        }
    }

    /// Upload a garment-only analysis (the user scanned a garment without a
    /// body scan). Idempotent while the garment-only session persists — reset
    /// on `newScan()`.
    func uploadGarmentOnlyIfNeeded(_ garment: GarmentTagModel) {
        let key = "garment-only"
        guard !uploadedSessionIds.contains(key) else {
            AppLog.upload.debug("skip duplicate garment-only upload")
            return
        }
        uploadedSessionIds.insert(key)
        setUploadStatus(.uploading)
        let height = userHeightCm
        let g = gender
        Task { [weak self] in
            let result = await BackendAPIClient.upload(
                garmentOnly: garment,
                heightCm: height,
                gender: g
            )
            await MainActor.run {
                self?.setUploadStatus(Self.mapStatus(result))
            }
        }
    }

    private func setUploadStatus(_ status: UploadStatus) {
        uploadStatus = status
        switch status {
        case .idle:
            AppLog.upload.debug("status: idle")
        case .uploading:
            AppLog.upload.info("status: uploading…")
        case .success(let id):
            AppLog.upload.info("status: success remoteId=\(id, privacy: .public)")
        case .failure(let msg):
            AppLog.upload.error("status: failure \(msg, privacy: .public)")
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
