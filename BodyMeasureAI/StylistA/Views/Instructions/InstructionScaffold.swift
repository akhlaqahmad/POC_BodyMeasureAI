//
//  InstructionScaffold.swift
//  BodyMeasureAI
//
//  Shared chrome for every pre-scan instruction screen: top bar with step
//  indicator + back chevron + exit, content slot, and bottom CTA row.
//

import SwiftUI

/// Describes where in the walkthrough the current screen sits so the header
/// can render a "Step n of 6" pill. Non-numbered stages (cover, gallery,
/// impact, ready) report `nil` for the step number.
enum InstructionStage: Equatable {
    case cover
    case step(Int, total: Int)
    case mistakes
    case impact
    case ready

    var label: String? {
        switch self {
        case .cover: return "Intro"
        case .step(let n, let total): return "Step \(n) of \(total)"
        case .mistakes: return "Common mistakes"
        case .impact: return "Why it matters"
        case .ready: return "Ready"
        }
    }
}

/// Layout wrapper that every step view uses. Keeps header + footer visually
/// consistent and routes the primary/secondary taps back up to the flow.
struct InstructionScaffold<Content: View>: View {
    let stage: InstructionStage
    let progress: Double        // 0…1
    let title: String
    let onBack: (() -> Void)?   // nil = hide chevron (first screen)
    let onExit: () -> Void
    let primary: CTA
    let secondary: CTA?
    let content: () -> Content

    struct CTA {
        let title: String
        let action: () -> Void
    }

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(Color("sBorder").opacity(0.4))
                ScrollView { content().padding(.bottom, SSpacing.xl) }
                footer
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: SSpacing.sm) {
            HStack(spacing: SSpacing.sm) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("sPrimary"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color("sSurface")))
                    }
                } else {
                    // keep layout stable on first screen
                    Color.clear.frame(width: 32, height: 32)
                }

                Spacer()

                if let label = stage.label {
                    Text(label.uppercased())
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sSecondary"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color("sSurface")))
                }

                Spacer()

                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("sPrimary"))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color("sSurface")))
                }
            }
            .padding(.horizontal, SSpacing.lg)
            .padding(.top, 56)

            // Slim progress bar under the pill row.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color("sBorder").opacity(0.35))
                    Capsule()
                        .fill(Color("sAccent"))
                        .frame(width: max(8, geo.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 3)
            .padding(.horizontal, SSpacing.lg)
            .padding(.top, SSpacing.xs)

            Text(title)
                .font(SFont.display(28, weight: .light))
                .foregroundStyle(Color("sPrimary"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.sm)
                .padding(.bottom, SSpacing.md)
        }
    }

    private var footer: some View {
        VStack(spacing: SSpacing.sm) {
            Button(action: primary.action) {
                Text(primary.title)
                    .font(SFont.label(15))
                    .tracking(1)
                    .foregroundStyle(Color("sBackground"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: SRadius.md)
                            .fill(Color("sAccent"))
                    )
            }
            .buttonStyle(.plain)

            if let secondary {
                Button(action: secondary.action) {
                    Text(secondary.title)
                        .font(SFont.label(13))
                        .tracking(1)
                        .foregroundStyle(Color("sSecondary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SSpacing.lg)
        .padding(.top, SSpacing.md)
        .padding(.bottom, SSpacing.xl)
        .background(Color("sBackground").ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Reusable bullets with a leading indicator dot

/// One rule in a rules list. 3DLOOK uses a filled black circle with a white
/// checkmark for correct rules and an X for violations; we mirror that with
/// system colours.
struct InstructionBullet: View {
    enum Kind { case good, bad, neutral }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: SSpacing.sm) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 22, height: 22)
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color("sBackground"))
                }
            }
            Text(text)
                .font(SFont.body(15))
                .foregroundStyle(Color("sPrimary"))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var symbol: String? {
        switch kind {
        case .good: return "checkmark"
        case .bad: return "xmark"
        case .neutral: return nil
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .good: return Color("sAccent")
        case .bad: return Color("sError")
        case .neutral: return Color("sPrimary").opacity(0.15)
        }
    }
}
