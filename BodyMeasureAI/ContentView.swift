//
//  ContentView.swift
//  BodyMeasureAI
//
//  Linear flow: Onboarding → BodyCapture → Results → GarmentCapture → GarmentResult → FinalScanResult.
//  Validation Mode from ResultsView.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            OnboardingView(
                heightCm: $coordinator.bodyCaptureViewModel.userHeightCm,
                gender: $coordinator.bodyCaptureViewModel.gender,
                onStartScan: {
                    coordinator.persistGender()
                    coordinator.requestCameraAndStartScan()
                },
                onOpenHistory: { coordinator.openScanHistory() }
            )
            .onAppear {
                coordinator.navigationPathBinding = $navigationPath
                coordinator.migrateLegacyGenderIfNeeded()
            }
            .navigationDestination(for: FlowStep.self) { step in
                switch step {
                case .bodyCapture:
                    TwoAngleScanView(
                        viewModel: coordinator.bodyCaptureViewModel,
                        coordinator: coordinator
                    )
                case .results:
                    if let result = coordinator.bodyResult {
                        ResultsView(
                            result: result,
                            onScanAgain: { coordinator.newScan() },
                            onContinueToGarment: { coordinator.continueToGarment() },
                            onValidationMode: { coordinator.openValidationMode() },
                            onStartMultiAngleScan: { coordinator.startMultiAngleScan() }
                        )
                    }
                case .garmentCapture:
                    GarmentCaptureView(
                        viewModel: coordinator.garmentCaptureViewModel,
                        coordinator: coordinator
                    )
                case .multiAngleCapture:
                    MultiAngleBodyScanView(
                        viewModel: coordinator.bodyCaptureViewModel,
                        coordinator: coordinator
                    )
                case .garmentResult:
                    if let body = coordinator.bodyResult, let garment = coordinator.garmentResult {
                        GarmentResultView(
                            image: coordinator.garmentCaptureViewModel.selectedImage,
                            result: garment,
                            onAddToWardrobe: { },
                            onDone: { coordinator.popLast() },
                            onCompleteScan: { coordinator.completeScan() }
                        )
                    }
                case .finalResult:
                    if let session = coordinator.buildSession() {
                        FinalScanResultView(
                            session: session,
                            onNewScan: { coordinator.newScan() }
                        )
                    }
                case .validationMode:
                    if let result = coordinator.bodyResult {
                        ValidationModeView(
                            bodyResult: result,
                            onDismiss: { coordinator.popLast() }
                        )
                    }
                case .scanHistory:
                    ScanHistoryView(
                        onOpenDetail: { item in coordinator.openScanHistoryDetail(item) },
                        onClose: { coordinator.popLast() }
                    )
                case .scanHistoryDetail(let id):
                    if let item = coordinator.historyItems.first(where: { $0.id == id }) {
                        ScanHistoryDetailView(
                            item: item,
                            onBack: { coordinator.popLast() }
                        )
                    }
                }
            }
        }
        .environmentObject(coordinator)
    }
}

#Preview {
    ContentView()
}
