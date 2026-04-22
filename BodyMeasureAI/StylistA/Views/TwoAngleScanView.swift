//
//  TwoAngleScanView.swift
//  BodyMeasureAI
//
//  Default scan flow: front capture → transition prompt → side capture.
//  Combines both into a single BodyScanResult with multiAngleMeasurements
//  (back omitted — users do the optional 3-angle flow separately).
//

import SwiftUI

struct TwoAngleScanView: View {
    @ObservedObject var viewModel: BodyCaptureViewModel
    @ObservedObject var coordinator: AppCoordinator

    /// Step order: capturing front → transition → capturing side → done.
    enum Step: Equatable {
        case capturingFront
        case transitionToSide
        case capturingSide
    }

    @State private var step: Step = .capturingFront
    @State private var frontResult: BodyScanResult?

    var body: some View {
        ZStack {
            switch step {
            case .capturingFront, .capturingSide:
                BodyCaptureView(viewModel: viewModel) { result in
                    handleCapture(result)
                }
                .overlay(alignment: .top) {
                    stepBanner
                }
            case .transitionToSide:
                TransitionInstructionView(
                    title: "Turn 90° to your side",
                    body: "Stand straight with your side facing the camera. Keep arms slightly away from your body so the outline is visible.",
                    continueTitle: "I'm ready",
                    onContinue: {
                        viewModel.resetLiveState()
                        step = .capturingSide
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { coordinator.popLast() }
                    .font(SFont.label(13))
            }
        }
        .onAppear { viewModel.resetLiveState() }
    }

    private var stepBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BODY SCAN")
                .font(SFont.label(11))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.6))
            Text(step == .capturingFront
                 ? "Step 1 of 2 · Front view"
                 : "Step 2 of 2 · Side view")
                .font(SFont.body(14))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, SSpacing.md)
        .padding(.top, 56)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.55), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func handleCapture(_ result: BodyScanResult) {
        switch step {
        case .capturingFront:
            frontResult = result
            step = .transitionToSide
        case .capturingSide:
            guard let front = frontResult else {
                // Shouldn't happen, but fall back to the side-only result.
                coordinator.bodyCaptured(result: result)
                return
            }
            var combined = front
            combined.multiAngleMeasurements = MultiAngleMeasurements(
                front: front.measurements,
                side: result.measurements,
                back: nil
            )
            coordinator.bodyCaptured(result: combined)
        case .transitionToSide:
            break
        }
        viewModel.clearResult()
    }
}

/// Interstitial between front and side captures. Plain SwiftUI; no camera
/// surface so the device can cool down and the user can reorient.
struct TransitionInstructionView: View {
    let title: String
    let body: String
    let continueTitle: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()
            VStack(alignment: .leading, spacing: SSpacing.lg) {
                Spacer()
                Text(title)
                    .font(SFont.display(34, weight: .light))
                    .foregroundStyle(Color("sPrimary"))
                Text(body)
                    .font(SFont.body(15))
                    .foregroundStyle(Color("sSecondary"))
                Spacer()
                Button(action: onContinue) {
                    HStack {
                        Text(continueTitle)
                            .font(SFont.label(15))
                            .tracking(1)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(Color("sBackground"))
                    .padding(.horizontal, SSpacing.lg)
                    .padding(.vertical, SSpacing.md)
                    .background(Color("sAccent"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                }
            }
            .padding(.horizontal, SSpacing.lg)
            .padding(.vertical, SSpacing.xxl)
        }
    }
}
