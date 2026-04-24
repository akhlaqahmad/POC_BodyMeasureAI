//
//  InstructionStep6SidePoseView.swift
//  BodyMeasureAI
//
//  Screen 7: side profile. Mirrors 3DLOOK's page 8 with its front/back
//  outline magnifier.
//

import SwiftUI

struct InstructionStep6SidePoseView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Side pose",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Got it", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.lg) {
                Image("instr.step6.hero")
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
                        text: "Turn to your left, same position, stand up straight."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Align your arms with the line of your pants."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Keep your legs and feet together."
                    )
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    Text("FRONT & BACK OUTLINE")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text("It's important to show both the front and back outline of your body — arms hanging by your hips (not behind or in front).")
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
