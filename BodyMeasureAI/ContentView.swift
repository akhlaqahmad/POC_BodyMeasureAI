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
                isFemale: $coordinator.bodyCaptureViewModel.isFemale,
                onStartScan: { coordinator.requestCameraAndStartScan() },
                onViewHistory: { coordinator.openHistory() }
            )
            .onAppear {
                coordinator.navigationPathBinding = $navigationPath
            }
            .navigationDestination(for: FlowStep.self) { step in
                switch step {
                case .bodyCapture:
                    BodyCaptureView(
                        viewModel: coordinator.bodyCaptureViewModel,
                        onCaptured: { result in coordinator.bodyCaptured(result: result) }
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
                case .history:
                    HistoryView()
                        .environmentObject(coordinator)
                case .bodyScanDetail(let item):
                    BodyScanDetailView(item: item)
                case .garmentScanDetail(let item):
                    GarmentScanDetailView(item: item)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
