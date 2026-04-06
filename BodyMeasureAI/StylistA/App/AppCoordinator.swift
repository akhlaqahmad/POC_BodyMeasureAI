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
    case history
    case bodyScanDetail(BodyScanHistoryItem)
    case garmentScanDetail(GarmentScanHistoryItem)
}

@MainActor
final class AppCoordinator: ObservableObject {
    /// Binding from ContentView so path updates trigger navigation (path in ViewModel can fail to update UI).
    var navigationPathBinding: Binding<NavigationPath>?

    var bodyCaptureViewModel: BodyCaptureViewModel
    var garmentCaptureViewModel: GarmentCaptureViewModel

    @Published var bodyResult: BodyScanResult?
    @Published var garmentResult: GarmentTagModel?

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
        // Persist body scan individually (fire-and-forget)
        Task {
            try? await ScanDatabaseService.shared.saveBodyScan(result)
        }
    }

    func continueToGarment() {
        appendToPath(.garmentCapture)
    }

    func garmentAnalysed(result: GarmentTagModel) {
        garmentResult = result
        appendToPath(.garmentResult)
        // Persist garment scan individually (fire-and-forget)
        Task {
            try? await ScanDatabaseService.shared.saveGarmentScan(result)
        }
    }

    func completeScan() {
        if let session = buildSession() {
            Task {
                do {
                    try await ScanDatabaseService.shared.saveScanSession(session)
                    print("Scan session successfully saved to Appwrite Database.")
                } catch {
                    print("Failed to save scan session: \(error.localizedDescription)")
                }
            }
        }
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
        clearPath()
    }

    func openHistory() {
        appendToPath(.history)
    }

    func openBodyScanDetail(_ item: BodyScanHistoryItem) {
        appendToPath(.bodyScanDetail(item))
    }

    func openGarmentScanDetail(_ item: GarmentScanHistoryItem) {
        appendToPath(.garmentScanDetail(item))
    }

    func popLast() {
        removeLastFromPath()
    }

    func buildSession() -> ScanSessionModel? {
        guard let body = bodyResult else { return nil }
        guard let garment = garmentResult else { return nil }
        return ScanSessionModel.from(bodyResult: body, garmentResult: garment)
    }
}
