//
//  InstructionStep2ModeView.swift
//  BodyMeasureAI
//
//  Screen 3: pick a capture mode — with a friend or by yourself. The
//  selection is stored on the coordinator and consumed by the capture
//  screen to decide between tap-to-capture and voice-guided self-capture.
//

import SwiftUI

struct InstructionStep2ModeView: View {
    let stage: InstructionStage
    let progress: Double
    @Binding var mode: ScanMode
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "Choose your mode",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Next", action: onNext),
            secondary: nil
        ) {
            VStack(spacing: SSpacing.md) {
                modeCard(
                    for: .withFriend,
                    imageName: "instr.step2.friend",
                    bullets: [
                        "A friend holds the phone at 90°.",
                        "Phone around hip height.",
                        "You stand 3–4 steps away."
                    ]
                )

                modeCard(
                    for: .bySelf,
                    imageName: "instr.step2.self",
                    bullets: [
                        "Prop the phone on a stable surface at 90°.",
                        "Voice guidance tells you when to pose.",
                        "Stand 3–4 steps away."
                    ]
                )
            }
            .padding(.horizontal, SSpacing.lg)
            .padding(.top, SSpacing.md)
        }
    }

    private func modeCard(
        for option: ScanMode,
        imageName: String,
        bullets: [String]
    ) -> some View {
        let isSelected = mode == option
        return Button {
            mode = option
        } label: {
            VStack(alignment: .leading, spacing: SSpacing.md) {
                HStack(alignment: .center, spacing: SSpacing.md) {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))

                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        HStack {
                            Text(option.displayName)
                                .font(SFont.heading(18))
                                .foregroundStyle(Color("sPrimary"))
                            Spacer()
                            Image(systemName: isSelected
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(
                                    isSelected
                                    ? Color("sAccent")
                                    : Color("sBorder")
                                )
                                .font(.system(size: 22))
                        }
                        Text(option == .withFriend
                             ? "Best if someone can help."
                             : "Best when you're alone.")
                            .font(SFont.body(13))
                            .foregroundStyle(Color("sSecondary"))
                    }
                }

                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    ForEach(bullets, id: \.self) { b in
                        InstructionBullet(kind: .neutral, text: b)
                    }
                }
            }
            .padding(SSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: SRadius.md)
                    .fill(Color("sSurface"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SRadius.md)
                    .stroke(
                        isSelected ? Color("sAccent") : Color("sBorder"),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
