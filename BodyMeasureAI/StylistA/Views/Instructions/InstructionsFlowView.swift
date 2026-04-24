//
//  InstructionsFlowView.swift
//  BodyMeasureAI
//
//  Root view for the 10-screen pre-scan walkthrough. Holds its own page
//  index and transitions; the outer NavigationStack sees a single push.
//  Flow order (derived from 3DLOOK's "How to take photos" playbook):
//    0 Cover → 1 Wear → 2 Mode → 3 Background → 4 Framing →
//    5 Front pose → 6 Side pose → 7 Mistakes gallery →
//    8 Impact studies → 9 Ready.
//

import SwiftUI

struct InstructionsFlowView: View {
    @ObservedObject var coordinator: AppCoordinator

    /// Page cursor. Transitions slide horizontally between steps.
    @State private var page: Int = 0
    /// Direction of the last move so the transition animates correctly when
    /// users tap Back.
    @State private var movingForward: Bool = true

    private static let total: Int = 10

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()
            currentPage
                .transition(
                    .asymmetric(
                        insertion: .move(edge: movingForward ? .trailing : .leading)
                                    .combined(with: .opacity),
                        removal: .move(edge: movingForward ? .leading : .trailing)
                                    .combined(with: .opacity)
                    )
                )
                .id(page)
        }
        .animation(.easeInOut(duration: 0.28), value: page)
    }

    // MARK: - Navigation helpers

    private func goNext() {
        guard page < Self.total - 1 else { return }
        movingForward = true
        page += 1
    }

    private func goBack() {
        if page == 0 {
            coordinator.popLast()
            return
        }
        movingForward = false
        page -= 1
    }

    private func exit() {
        coordinator.popLast()
    }

    private func onReady() {
        coordinator.instructionsAcknowledgedStartScan()
    }

    private var progress: Double {
        Double(page + 1) / Double(Self.total)
    }

    // MARK: - Page switch

    @ViewBuilder
    private var currentPage: some View {
        switch page {
        case 0:
            InstructionCoverView(
                stage: .cover,
                progress: progress,
                onStart: goNext,
                onExit: exit
            )
        case 1:
            InstructionStep1WearView(
                stage: .step(1, total: 6),
                progress: progress,
                gender: coordinator.gender,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 2:
            InstructionStep2ModeView(
                stage: .step(2, total: 6),
                progress: progress,
                mode: Binding(
                    get: { coordinator.scanMode },
                    set: { coordinator.scanMode = $0 }
                ),
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 3:
            InstructionStep3BackgroundView(
                stage: .step(3, total: 6),
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 4:
            InstructionStep4FramingView(
                stage: .step(4, total: 6),
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 5:
            InstructionStep5FrontPoseView(
                stage: .step(5, total: 6),
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 6:
            InstructionStep6SidePoseView(
                stage: .step(6, total: 6),
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 7:
            InstructionMistakesGalleryView(
                stage: .mistakes,
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        case 8:
            InstructionImpactStudiesView(
                stage: .impact,
                progress: progress,
                onNext: goNext,
                onBack: goBack,
                onExit: exit
            )
        default:
            InstructionReadyView(
                stage: .ready,
                progress: 1.0,
                mode: coordinator.scanMode,
                onStartScan: onReady,
                onBack: goBack,
                onExit: exit
            )
        }
    }
}
