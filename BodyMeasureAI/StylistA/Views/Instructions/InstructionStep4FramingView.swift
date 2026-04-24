//
//  InstructionStep4FramingView.swift
//  BodyMeasureAI
//
//  Screen 5: the 70% rule — body fills most of the frame, hands and feet
//  inside. Mirrors 3DLOOK's page 6 with its green frame and proximity bar.
//

import SwiftUI

struct InstructionStep4FramingView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Stand in frame",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Got it", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.lg) {
                // Hero — the 70% framing illustration with a proximity gauge.
                HStack(alignment: .center, spacing: SSpacing.md) {
                    Image("instr.step4.gauge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18)
                        .frame(height: 320)
                    Image("instr.step4.hero")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 320)
                        .background(Color("sSurface"))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    InstructionBullet(
                        kind: .good,
                        text: "Keep hands and feet within the frame."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Your body should cover 70% of the frame."
                    )
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    Text("DURING THE SCAN")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text("You'll see this bar on the side of the camera. Green = perfect distance. Step forward or back until it settles in the middle.")
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
