//
//  InstructionImpactStudiesView.swift
//  BodyMeasureAI
//
//  Screen 9: "Why this matters" — four scan-vs-photo impact studies showing
//  the measurement error each protocol violation causes. Verbatim body copy
//  from 3DLOOK's pages 11–14.
//

import SwiftUI

struct InstructionImpactStudiesView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Why this matters",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "I'm ready", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.lg) {
                Text("Each rule maps to a specific measurement error we've seen in real scans. This is what the AI sees when the protocol isn't followed.")
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sSecondary"))
                    .padding(.horizontal, SSpacing.lg)

                ForEach(studies, id: \.title) { s in
                    studyCard(s)
                }
            }
            .padding(.top, SSpacing.md)
        }
    }

    private func studyCard(_ s: Study) -> some View {
        VStack(alignment: .leading, spacing: SSpacing.sm) {
            Text(s.title)
                .font(SFont.heading(17))
                .foregroundStyle(Color("sAccent"))
            Image(s.asset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
            Text(s.body)
                .font(SFont.body(13))
                .foregroundStyle(Color("sPrimary"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SSpacing.md)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .padding(.horizontal, SSpacing.lg)
    }

    private struct Study { let title: String; let body: String; let asset: String }

    private var studies: [Study] {
        [
            .init(
                title: "Loose clothing and hairstyle",
                body: "Loose clothing hides your body's true shape, leading to inaccuracies in measurements. Tight clothing lets our AI understand the definition of your body. Long hair that isn't tied up makes it difficult for our AI to detect upper body measurements accurately.",
                asset: "instr.impact.loose.front"
            ),
            .init(
                title: "Skirt, dress and heels",
                body: "Heels elevate height and alter stance, affecting measurements of stature and posture. A skirt or dress obscures the contours of the lower body — the scan won't accurately represent your real shape.",
                asset: "instr.impact.skirt"
            ),
            .init(
                title: "Incorrect pose",
                body: "When arms and hands are too close to the body, they can be mistaken for part of the torso, causing measurement errors. Correct arm and hand placement is essential.",
                asset: "instr.impact.pose"
            ),
            .init(
                title: "Background and hand position",
                body: "For the front pose, arms must be held away from the body in an A-pose, not obstructing the torso. In the side pose, arms should align with the body so the AI can see the front and back outlines clearly.",
                asset: "instr.impact.bg"
            )
        ]
    }
}
