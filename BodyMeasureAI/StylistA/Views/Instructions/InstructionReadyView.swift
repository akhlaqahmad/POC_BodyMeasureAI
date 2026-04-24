//
//  InstructionReadyView.swift
//  BodyMeasureAI
//
//  Screen 10: "You're ready." A live checklist that reflects the
//  walkthrough's selections, then a CTA that hands off to the camera.
//

import SwiftUI

struct InstructionReadyView: View {
    let stage: InstructionStage
    let progress: Double
    let mode: ScanMode
    let onStartScan: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "You're ready",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "Start scan", action: onStartScan),
            secondary: .init(title: "Review instructions", action: onBack)
        ) {
            VStack(alignment: .leading, spacing: SSpacing.lg) {
                Text("Here's a quick recap of what you've set up. We'll guide you in real time during the scan itself.")
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sSecondary"))
                    .padding(.horizontal, SSpacing.lg)

                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    checkRow("Outfit ready", detail: "Tight clothing, hair up, no belt or heels.")
                    checkRow("Mode: \(mode.displayName)", detail: mode == .bySelf
                             ? "Phone propped — voice guidance on."
                             : "A friend will hold the phone at hip height.")
                    checkRow("Clean background", detail: "Plain, contrasting wall with good light.")
                    checkRow("A-pose and side-pose memorised", detail: "Arms out front, down to the side for profile.")
                }
                .padding(SSpacing.md)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                .padding(.horizontal, SSpacing.lg)
            }
            .padding(.top, SSpacing.md)
        }
    }

    private func checkRow(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: SSpacing.sm) {
            ZStack {
                Circle().fill(Color("sAccent")).frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color("sBackground"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SFont.label(14))
                    .foregroundStyle(Color("sPrimary"))
                Text(detail)
                    .font(SFont.body(12))
                    .foregroundStyle(Color("sSecondary"))
            }
            Spacer(minLength: 0)
        }
    }
}
