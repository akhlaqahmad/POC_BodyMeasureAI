//
//  MultiAngleBodyScanView.swift
//  BodyMeasureAI
//
//  Simple 3-angle (front / side / back) capture flow that reuses BodyCaptureView.
//  It does not change the existing single-angle scan; it just wraps three
//  consecutive captures before navigating to the existing ResultsView.
//

import SwiftUI
import Vision

struct MultiAngleBodyScanView: View {
    @ObservedObject var viewModel: BodyCaptureViewModel
    @ObservedObject var coordinator: AppCoordinator

    /// 0 = front, 1 = side, 2 = back.
    @State private var step: Int = 0
    @State private var didInitialiseFromExistingResult = false
    @State private var frontResult: BodyScanResult?
    @State private var sideResult: BodyScanResult?
    @State private var backResult: BodyScanResult?

    private var currentStepTitle: String {
        if frontResult != nil {
            // Front already captured earlier in the flow (Results screen),
            // so multi-angle flow is only collecting side + back.
            switch step {
            case 1: return "Step 2 of 3 · Side view"
            default: return "Step 3 of 3 · Back view"
            }
        } else {
            switch step {
            case 0: return "Step 1 of 3 · Front view"
            case 1: return "Step 2 of 3 · Side view"
            default: return "Step 3 of 3 · Back view"
            }
        }
    }

    private var currentStepInstruction: String {
        if frontResult != nil {
            // Front pose already known; guide only side/back.
            switch step {
            case 1:
                return "Turn 90° to the side · Keep full body visible."
            default:
                return "Turn so your back faces the camera · Full body in frame."
            }
        } else {
            switch step {
            case 0:
                return "Face the camera · Arms slightly out · Full body in frame."
            case 1:
                return "Turn 90° to the side · Keep full body visible."
            default:
                return "Turn so your back faces the camera · Full body in frame."
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            BodyCaptureView(viewModel: viewModel, hideTopInstruction: true) { result in
                handleCapture(result)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("3-ANGLE BODY SCAN")
                    .font(SFont.label(11))
                    .tracking(3)
                    .foregroundStyle(Color("sTertiary"))
                Text(currentStepTitle)
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sPrimary"))
                Text(currentStepInstruction)
                    .font(SFont.body(12))
                    .foregroundStyle(Color("sSecondary"))
            }
            .padding(SSpacing.md)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color("sBackground").opacity(0.9), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    coordinator.popLast()
                }
                .font(SFont.label(13))
            }
        }
        .onAppear {
            // If we already have a front-view result from the standard scan,
            // treat that as step 1 and only ask the user for side + back.
            if !didInitialiseFromExistingResult {
                didInitialiseFromExistingResult = true
                if let existingFront = coordinator.bodyResult {
                    frontResult = existingFront
                    step = 1
                }
            }
        }
    }

    private func handleCapture(_ result: BodyScanResult) {
        if frontResult != nil {
            // We already have front; collect side then back.
            switch step {
            case 1:
                sideResult = result
                step = 2
            default:
                backResult = result
                let front = frontResult ?? result
                if let side = sideResult, let back = backResult {
                    var combined = front
                    combined.multiAngleMeasurements = MultiAngleMeasurements(
                        front: front.measurements,
                        side: side.measurements,
                        back: back.measurements
                    )
                    coordinator.bodyCaptured(result: combined)
                } else {
                    coordinator.bodyCaptured(result: front)
                }
            }
        } else {
            switch step {
            case 0:
                frontResult = result
                step = 1
            case 1:
                sideResult = result
                step = 2
            default:
                backResult = result
                let front = frontResult ?? result
                if let side = sideResult, let back = backResult {
                    var combined = front
                    combined.multiAngleMeasurements = MultiAngleMeasurements(
                        front: front.measurements,
                        side: side.measurements,
                        back: back.measurements
                    )
                    coordinator.bodyCaptured(result: combined)
                } else {
                    coordinator.bodyCaptured(result: front)
                }
            }
        }
        // Clear capturedResult and reset live detection state so the next
        // angle starts fresh (stability counter, frame buffer, etc.).
        viewModel.clearResult()
        viewModel.resetLiveState()
    }
}

