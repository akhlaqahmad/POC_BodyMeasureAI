//
//  InstructionStep3BackgroundView.swift
//  BodyMeasureAI
//
//  Screen 4: good vs bad background, with lighting + contrast tips. Mirrors
//  3DLOOK's page 5 side-by-side comparison.
//

import SwiftUI

struct InstructionStep3BackgroundView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Background",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Got it", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.lg) {
                HStack(spacing: SSpacing.sm) {
                    comparisonCard(
                        image: "instr.step3.bad",
                        kind: .bad,
                        caption: "Cluttered and same-colour objects confuse our AI."
                    )
                    comparisonCard(
                        image: "instr.step3.good",
                        kind: .good,
                        caption: "Clean background, contrasting your clothes, well-lit."
                    )
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    InstructionBullet(
                        kind: .good,
                        text: "Background should be clean and contrast your body and clothing."
                    )
                    InstructionBullet(
                        kind: .good,
                        text: "Make sure you are in a well-lit room."
                    )
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    Text("PRO TIP")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text("Dark clothing against a dark couch is the #1 silent cause of bad scans.")
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

    private func comparisonCard(
        image: String,
        kind: InstructionBullet.Kind,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: SSpacing.sm) {
            ZStack(alignment: .topLeading) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))

                Image(systemName: kind == .good ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        kind == .good ? Color("sAccent") : Color("sError")
                    )
                    .padding(SSpacing.sm)
            }
            Text(caption)
                .font(SFont.body(12))
                .foregroundStyle(Color("sSecondary"))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
