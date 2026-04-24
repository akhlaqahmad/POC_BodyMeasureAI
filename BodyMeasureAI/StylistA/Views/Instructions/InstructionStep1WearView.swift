//
//  InstructionStep1WearView.swift
//  BodyMeasureAI
//
//  Screen 2: clothing guidance. Gender-branched because the rule list differs.
//  Mirrors 3DLOOK's pages 2 (male) and 3 (female).
//

import SwiftUI

struct InstructionStep1WearView: View {
    let stage: InstructionStage
    let progress: Double
    let gender: Gender
    let onNext: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    @State private var showingWhySheet = false

    var body: some View {
        InstructionScaffold(
            stage: stage,
            progress: progress,
            title: "What to wear",
            onBack: onBack,
            onExit: onExit,
            primary: .init(title: "I'm dressed — next", action: onNext),
            secondary: .init(
                title: "Why does clothing matter?",
                action: { showingWhySheet = true }
            )
        ) {
            VStack(spacing: SSpacing.lg) {
                // Hero model image
                Image(heroAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .frame(maxWidth: .infinity)
                    .background(Color("sSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                    .padding(.horizontal, SSpacing.lg)

                // Rules
                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    ForEach(rules, id: \.self) { rule in
                        InstructionBullet(kind: .good, text: rule)
                    }
                }
                .padding(.horizontal, SSpacing.lg)

                // Examples grid
                VStack(alignment: .leading, spacing: SSpacing.sm) {
                    Text("EXAMPLES")
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                        .padding(.horizontal, SSpacing.lg)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: SSpacing.sm),
                                  GridItem(.flexible(), spacing: SSpacing.sm)],
                        spacing: SSpacing.sm
                    ) {
                        ForEach(exampleAssets, id: \.self) { name in
                            Image(name)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 140)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .background(Color("sSurface"))
                                .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                        }
                    }
                    .padding(.horizontal, SSpacing.lg)
                }
            }
            .padding(.top, SSpacing.md)
        }
        .sheet(isPresented: $showingWhySheet) {
            WhyClothingMattersSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var rules: [String] {
        switch gender {
        case .male:
            return [
                "Wear a tight top (tank or compression tee).",
                "No belt and no accessories.",
                "Wear tight leggings or fitted bottoms.",
                "Wear flat shoes or go barefoot."
            ]
        case .female:
            return [
                "Put your hair up.",
                "Wear a tight tee or tank top — no bra.",
                "No belt and no accessories.",
                "Wear tight leggings or bike shorts.",
                "No high heels — flat shoes or bare feet."
            ]
        case .nonBinary:
            return [
                "Wear a tight top (no bra if applicable).",
                "Tie long hair up and off the shoulders.",
                "No belt and no accessories.",
                "Wear tight leggings or fitted bottoms.",
                "Flat shoes or bare feet — no heels."
            ]
        }
    }

    private var heroAssetName: String {
        switch gender {
        case .male: return "instr.step1.male.hero"
        case .female, .nonBinary: return "instr.step1.female.hero"
        }
    }

    private var exampleAssets: [String] {
        switch gender {
        case .male:
            return [
                "instr.step1.male.ex1",
                "instr.step1.male.ex2",
                "instr.step1.male.ex3",
                "instr.step1.male.ex4"
            ]
        case .female, .nonBinary:
            return [
                "instr.step1.female.ex1",
                "instr.step1.female.ex2",
                "instr.step1.female.ex3",
                "instr.step1.female.ex4"
            ]
        }
    }
}

// MARK: - Bottom sheet explaining the rule's consequences.

private struct WhyClothingMattersSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SSpacing.md) {
                Text("Why it matters")
                    .font(SFont.display(24, weight: .light))
                    .foregroundStyle(Color("sPrimary"))
                    .padding(.top, SSpacing.lg)

                Image("instr.impact.loose.front")
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))

                rule(
                    title: "Accuracy",
                    body: "Loose clothing hides your body's true shape, leading to inaccuracies in measurements."
                )
                rule(
                    title: "Shape definition",
                    body: "Tight clothing lets our AI understand the definition of your body for precise measurements."
                )
                rule(
                    title: "Hair",
                    body: "Long hair that isn't tied up makes it difficult for our AI to detect upper-body measurements accurately."
                )
            }
            .padding(.horizontal, SSpacing.lg)
            .padding(.bottom, SSpacing.xl)
        }
        .background(Color("sBackground").ignoresSafeArea())
    }

    private func rule(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: SSpacing.xs) {
            Text(title.uppercased())
                .font(SFont.label(11))
                .tracking(2)
                .foregroundStyle(Color("sTertiary"))
            Text(body)
                .font(SFont.body(14))
                .foregroundStyle(Color("sPrimary"))
        }
    }
}
