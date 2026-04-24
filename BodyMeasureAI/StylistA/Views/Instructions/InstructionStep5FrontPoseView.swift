//
//  InstructionStep5FrontPoseView.swift
//  BodyMeasureAI
//
//  Screen 6: the A-pose for the front shot. Mirrors 3DLOOK's page 7 with
//  its two outline magnifiers (arm gap, leg gap).
//

import SwiftUI

struct InstructionStep5FrontPoseView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Front pose",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Got it", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.lg) {
                Image("instr.step5.hero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .frame(maxWidth: .infinity)
                    .background(Color("sSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                    .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    InstructionBullet(
                        kind: .good,
                        text: "Stand up straight, facing the camera."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Spread your arms away from your hips — A-pose."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Keep your feet apart from each other."
                    )
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    Text("THE OUTLINE MATTERS")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text("Our AI needs to see the full outline of your arms and legs — there must be a clear gap between your arms and torso, and between your legs.")
                        .font(SFont.body(14))
                        .foregroundStyle(Color("sPrimary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SSpacing.md)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                .padding(.horizontal, SSpacing.lg)
            }
            .padding(.top, SSpacing.md)
        }
    }
}
