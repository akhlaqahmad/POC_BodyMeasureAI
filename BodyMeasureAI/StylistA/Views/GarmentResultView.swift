//
//  GarmentResultView.swift
//  BodyMeasureAI
//
//  Displays garment analysis: thumbnail, tag grid, confidence, Export JSON, collapsible raw JSON.
//

import SwiftUI
import UIKit

struct GarmentResultView: View {
    let image: UIImage?
    let result: GarmentTagModel
    let onAddToWardrobe: () -> Void
    let onDone: () -> Void
    var onCompleteScan: (() -> Void)? = nil

    @State private var rawJSONExpanded = false

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SSpacing.xl) {

                    // Header
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        Text("GARMENT SCAN")
                            .font(SFont.label(11))
                            .tracking(3)
                            .foregroundStyle(Color("sTertiary"))
                        Text("Analysis")
                            .font(SFont.display(34, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SSpacing.lg)
                    .padding(.top, SSpacing.xl)
                    .padding(.bottom, SSpacing.md)

                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                            .softShadow()
                    }

                    // Row 1: Category, Subcategory
                    HStack(spacing: SSpacing.sm) {
                        TagPill(label: "Category", value: result.category.rawValue)
                        TagPill(label: "Subcategory", value: result.subcategory)
                    }

                    // Row 2: Pattern, Silhouette
                    HStack(spacing: SSpacing.sm) {
                        TagPill(label: "Pattern", value: result.pattern.rawValue)
                        TagPill(label: "Silhouette", value: result.silhouette.rawValue)
                    }

                    // Row 3: Length, Visual weight, Neckline (if top/dress), Sleeve (if top/dress)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SSpacing.sm) {
                        TagPill(label: "Length", value: result.garmentLength.rawValue)
                        TagPill(label: "Visual weight", value: result.visualWeight.rawValue)
                        if let n = result.neckline, n != .unknown {
                            TagPill(label: "Neckline", value: n.rawValue)
                        }
                        if let s = result.sleeveLength, s != .unknown {
                            TagPill(label: "Sleeve", value: s.rawValue)
                        }
                    }

                    // Row 4: Color card only
                    if !result.primaryColors.isEmpty {
                        ColorPills(colors: result.primaryColors)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Text("Confidence: \(Int(result.classificationConfidence * 100))%")
                        .font(SFont.body(13))
                        .foregroundStyle(Color("sTertiary"))

                    // Actions
                    VStack(spacing: SSpacing.sm) {
                        if let complete = onCompleteScan {
                            Button(action: complete) {
                                HStack {
                                    Text("Complete Scan")
                                        .font(SFont.label(15))
                                        .tracking(0.5)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                }
                                .foregroundStyle(Color("sBackground"))
                                .padding(SSpacing.md)
                                .background(Color("sAccent"))
                                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: SSpacing.sm) {
                            Button(action: onAddToWardrobe) {
                                Text("Add to Wardrobe")
                                    .font(SFont.label(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            }
                            .buttonStyle(.plain)
                            Button(action: onDone) {
                                Text("Done")
                                    .font(SFont.label(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { exportJSON() }) {
                            Text("Export JSON")
                                .font(SFont.label(14))
                                .foregroundStyle(Color("sPrimary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SSpacing.md)
                                .background(Color("sSurfaceElevated"))
                                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }
                        .buttonStyle(.plain)
                    }

                    DisclosureGroup("Raw JSON", isExpanded: $rawJSONExpanded) {
                        if let json = result.prettyPrintedJSON() {
                            Text(json)
                                .font(SFont.mono(11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(SSpacing.md)
                                .background(Color("sSurfaceElevated"))
                                .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                        }
                    }
                    .font(SFont.label(12))
                    .foregroundStyle(Color("sPrimary"))
                    .padding(.vertical, SSpacing.xs)

                    Spacer().frame(height: SSpacing.xxl)
                }
                .padding(.horizontal, SSpacing.lg)
            }
        }
        .navigationBarHidden(true)
    }

    private func exportJSON() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        guard let json = result.prettyPrintedJSON(),
              let data = json.data(using: .utf8) else { return }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("garment-analysis.json")
        try? data.write(to: temp)
        let vc = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }
}

// MARK: - Tag pill

private struct TagPill: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(SFont.label(9))
                .tracking(1.5)
                .foregroundStyle(Color("sTertiary"))
            Text(value)
                .font(SFont.heading(15, weight: .medium))
                .foregroundStyle(Color("sPrimary"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SSpacing.md)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .softShadow()
    }
}

// MARK: - Color pills from hex swatches

private struct ColorPills: View {
    /// Hex colour strings in order of coverage (e.g. ["#2C4A8F", "#DDE1E8"])
    let colors: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Colors (\(colors.count))")
                .font(SFont.label(11))
                .foregroundStyle(Color("sTertiary"))
            FlexibleColorRow(colors: colors)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SSpacing.md)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .softShadow()
    }
}

/// Flexible row that wraps color pills — prevents text from breaking (no vertical splitting)
private struct FlexibleColorRow: View {
    /// Hex colours (e.g. "#2C4A8F")
    let colors: [String]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.self) { hex in
                let swatch = color(fromHex: hex)
                HStack(spacing: 4) {
                    Circle()
                        .fill(swatch)
                        .frame(width: 12, height: 12)
                    Text(hex)
                        .font(SFont.label(12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color("sSurfaceElevated"))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func color(fromHex hex: String) -> Color {
        guard hex.hasPrefix("#"), hex.count == 7,
              let value = Int(hex.dropFirst(), radix: 16) else { return Color.gray }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
