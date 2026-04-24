//
//  InstructionCoverView.swift
//  BodyMeasureAI
//
//  Screen 0: sets expectations before the 6-step walkthrough.
//

import SwiftUI

struct InstructionCoverView: View {
    let stage: InstructionStage
    let progress: Double
    let onStart: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Let's get accurate\nmeasurements",
            onBack: nil,
            onExit: onExit,
            primary: .init(title: "Start", action: onStart),
            secondary: nil
        ) {
            VStack(alignment: .leading, spacing: SSpacing.lg) {
                Text("A 30-second walkthrough before your first scan. Six short steps, each fixing one thing at a time.")
                    .font(SFont.body(16))
                    .foregroundStyle(Color("sSecondary"))
                    .padding(.horizontal, SSpacing.lg)

                HStack(spacing: SSpacing.md) {
                    coverTile(icon: "tshirt", label: "Clothing")
                    coverTile(icon: "figure.stand", label: "Pose")
                    coverTile(icon: "camera.viewfinder", label: "Framing")
                }
                .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    Text("WHY IT MATTERS")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text("Following the protocol is what makes the difference between a good-looking photo and an accurate measurement. The more closely you match it, the tighter our AI's error margins.")
                        .font(SFont.body(14))
                        .foregroundStyle(Color("sPrimary"))
                }
                .padding(SSpacing.lg)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                .padding(.horizontal, SSpacing.lg)
            }
            .padding(.top, SSpacing.md)
        }
    }

    private func coverTile(icon: String, label: String) -> some View {
        VStack(spacing: SSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color("sPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, SSpacing.lg)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
            Text(label.uppercased())
                .font(SFont.label(11))
                .tracking(2)
                .foregroundStyle(Color("sSecondary"))
        }
    }
}
