//
//  InstructionMistakesGalleryView.swift
//  BodyMeasureAI
//
//  Screens 8: the "common mistakes" gallery. 5 front-view mistakes +
//  4 side-view mistakes. Mirrors 3DLOOK's pages 9 and 10.
//

import SwiftUI

struct InstructionMistakesGalleryView: View {
    let stage: InstructionStage
    let progress: Double
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Common mistakes",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Continue", action: onNext),
            secondary: nil
        ) {
            VStack(alignment: .leading, spacing: SSpacing.lg) {
                sectionHeader("FRONT POSE — AVOID")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SSpacing.sm) {
                        ForEach(frontMistakes, id: \.asset) { m in
                            mistakeCard(image: m.asset, caption: m.caption)
                        }
                    }
                    .padding(.horizontal, SSpacing.lg)
                }

                sectionHeader("SIDE POSE — AVOID")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: SSpacing.sm) {
                        ForEach(sideMistakes, id: \.asset) { m in
                            mistakeCard(image: m.asset, caption: m.caption)
                        }
                    }
                    .padding(.horizontal, SSpacing.lg)
                }
            }
            .padding(.top, SSpacing.md)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(SFont.label(11))
            .tracking(2)
            .foregroundStyle(Color("sTertiary"))
            .padding(.horizontal, SSpacing.lg)
    }

    private func mistakeCard(image: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: SSpacing.xs) {
            ZStack(alignment: .topLeading) {
                Image(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 240)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("sError"))
                    .padding(SSpacing.xs)
            }
            Text(caption)
                .font(SFont.body(12))
                .foregroundStyle(Color("sSecondary"))
                .frame(width: 160, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct Mistake { let asset: String; let caption: String }

    private var frontMistakes: [Mistake] {
        [
            .init(asset: "instr.mistake.front1",
                  caption: "Don't put arms on hips, crossed, or over the head."),
            .init(asset: "instr.mistake.front2",
                  caption: "Arms and legs should not be together."),
            .init(asset: "instr.mistake.front3",
                  caption: "Stand up straight — don't lean or hunch."),
            .init(asset: "instr.mistake.front4",
                  caption: "Don't tilt the head."),
            .init(asset: "instr.mistake.front5",
                  caption: "Arms should be away from the body, not aligned with pants.")
        ]
    }

    private var sideMistakes: [Mistake] {
        [
            .init(asset: "instr.mistake.side1",
                  caption: "Arms should be placed along the line of your pants."),
            .init(asset: "instr.mistake.side2",
                  caption: "Don't angle your body — keep a clean 90° profile."),
            .init(asset: "instr.mistake.side3",
                  caption: "Legs and feet should be together."),
            .init(asset: "instr.mistake.side4",
                  caption: "Don't lean or slouch.")
        ]
    }
}
