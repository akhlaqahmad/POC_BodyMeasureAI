//
//  MultiAngleBodyScanView.swift
//  BodyMeasureAI
//
//  Guided 3-angle (front / side / back) capture flow. Each capture step
//  mounts `BodyCaptureView` fresh via a switch; between captures a
//  `TransitionInstructionView` unmounts the camera so that:
//    1. `viewModel.resetLiveState()` puts stability counters back to zero,
//    2. `BodyCaptureView.onAppear` rewires `.onChange(isReadyForAutoCapture)`
//       and creates a fresh `SpeechGuidanceService` (so prompts speak again),
//    3. The user has a beat to reorient (turn 90°, turn around).
//
//  Without the transition screens the same `BodyCaptureView` stays mounted
//  across steps and `isReadyForAutoCapture` latches to `true` — the onChange
//  never fires again and the flow hangs. See TwoAngleScanView for the same
//  pattern.
//

import SwiftUI
import Vision
import os

struct MultiAngleBodyScanView: View {
    @ObservedObject var viewModel: BodyCaptureViewModel
    @ObservedObject var coordinator: AppCoordinator

    /// Ordered capture steps interleaved with reorient instructions.
    enum Step: Equatable {
        case capturingFront
        case transitionToSide
        case capturingSide
        case transitionToBack
        case capturingBack
    }

    @State private var step: Step = .capturingFront
    @State private var didInitialiseFromExistingResult = false
    @State private var frontResult: BodyScanResult?
    @State private var sideResult: BodyScanResult?
    @State private var backResult: BodyScanResult?

    var body: some View {
        ZStack {
            switch step {
            case .capturingFront, .capturingSide, .capturingBack:
                BodyCaptureView(
                    viewModel: viewModel,
                    onCaptured: { result in handleCapture(result) },
                    phaseLabel: phaseLabel,
                    phaseSubtitle: currentStepInstruction
                )
            case .transitionToSide:
                TransitionInstructionView(
                    title: "Turn 90° to your side",
                    message: "Stand straight with one shoulder facing the camera. Keep arms slightly out so your outline stays visible.",
                    continueTitle: "I'm ready",
                    onContinue: {
                        AppLog.lifecycle.info("3angle: user ready → capturingSide")
                        viewModel.resetLiveState()
                        step = .capturingSide
                    }
                )
            case .transitionToBack:
                TransitionInstructionView(
                    title: "Turn around — back to camera",
                    message: "Turn so your back faces the camera. Keep your whole body in frame.",
                    continueTitle: "I'm ready",
                    onContinue: {
                        AppLog.lifecycle.info("3angle: user ready → capturingBack")
                        viewModel.resetLiveState()
                        step = .capturingBack
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    AppLog.lifecycle.info("3angle: user cancelled at step=\(String(describing: self.step), privacy: .public)")
                    coordinator.popLast()
                }
                .font(SFont.label(13))
                .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.black.opacity(0.5), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            AppLog.lifecycle.info("3angle: MultiAngleBodyScanView.onAppear")
            // If we already have a front-view result from the standard scan,
            // skip the front capture and enter the transition to side.
            if !didInitialiseFromExistingResult {
                didInitialiseFromExistingResult = true
                if let existingFront = coordinator.bodyResult {
                    AppLog.lifecycle.info("3angle: existing front result found — skipping front capture")
                    frontResult = existingFront
                    step = .transitionToSide
                } else {
                    AppLog.lifecycle.info("3angle: starting fresh at capturingFront")
                }
            }
        }
        .keepScreenAwake()
    }

    private var currentStepTitle: String {
        switch step {
        case .capturingFront:  return "Step 1 of 3 · Front view"
        case .capturingSide:   return "Step 2 of 3 · Side view"
        case .capturingBack:   return "Step 3 of 3 · Back view"
        // Phase label is only read when a capturing view is mounted; these
        // transition cases don't show it but we give them sensible values.
        case .transitionToSide: return "Step 2 of 3 · Side view"
        case .transitionToBack: return "Step 3 of 3 · Back view"
        }
    }

    private var currentStepInstruction: String {
        switch step {
        case .capturingFront:
            return "Face the camera · Arms slightly out · Full body in frame."
        case .capturingSide:
            return "Turn 90° to the side · Keep full body visible."
        case .capturingBack:
            return "Turn so your back faces the camera · Full body in frame."
        case .transitionToSide, .transitionToBack:
            return ""
        }
    }

    private var phaseLabel: String {
        "GUIDED SCAN · \(currentStepTitle.uppercased())"
    }

    private func handleCapture(_ result: BodyScanResult) {
        switch step {
        case .capturingFront:
            AppLog.lifecycle.info(
                "3angle: front captured conf=\(result.measurements.captureConfidence, format: .fixed(precision: 2), privacy: .public) → transitionToSide"
            )
            frontResult = result
            step = .transitionToSide
        case .capturingSide:
            AppLog.lifecycle.info(
                "3angle: side captured conf=\(result.measurements.captureConfidence, format: .fixed(precision: 2), privacy: .public) → transitionToBack"
            )
            sideResult = result
            step = .transitionToBack
        case .capturingBack:
            AppLog.lifecycle.info(
                "3angle: back captured conf=\(result.measurements.captureConfidence, format: .fixed(precision: 2), privacy: .public) → combining"
            )
            backResult = result
            let front = frontResult ?? result
            if let side = sideResult, let back = backResult {
                var combined = front
                combined.multiAngleMeasurements = MultiAngleMeasurements(
                    front: front.measurements,
                    side: side.measurements,
                    back: back.measurements
                )
                AppLog.lifecycle.info("3angle: 3-angle session complete — navigating to results")
                coordinator.bodyCaptured(result: combined)
            } else {
                AppLog.lifecycle.error("3angle: missing intermediate result — falling back to front only")
                coordinator.bodyCaptured(result: front)
            }
        case .transitionToSide, .transitionToBack:
            // Should not happen — BodyCaptureView isn't mounted during
            // transitions, so it can't call onCaptured.
            AppLog.lifecycle.error("3angle: unexpected capture during transition step")
        }
        // Clear capturedResult so the next BodyCaptureView mount starts clean.
        viewModel.clearResult()
    }
}
