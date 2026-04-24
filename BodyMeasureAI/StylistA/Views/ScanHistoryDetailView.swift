//
//  ScanHistoryDetailView.swift
//  BodyMeasureAI
//
//  Detail view for a single past scan (body measurements + classification +
//  all garments). Read-only mirror of FinalScanResultView, data source is the
//  backend instead of live capture state.
//

import SwiftUI

struct ScanHistoryDetailView: View {
    let item: ScanHistoryItem
    let onBack: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .full
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SSpacing.xl) {

                    // Header
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(width: 36, height: 36)
                                    .background(Color("sSurface"))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }

                        Text("SCAN · \(Int(item.captureConfidence * 100))% conf")
                            .font(SFont.label(11))
                            .tracking(3)
                            .foregroundStyle(Color("sTertiary"))
                        Text(Self.dateFormatter.string(from: item.scanTimestamp))
                            .font(SFont.display(26, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                    }

                    // Classification
                    if let c = item.bodyClassification {
                        VStack(alignment: .leading, spacing: SSpacing.sm) {
                            Text("STYLE INSIGHT")
                                .font(SFont.label(10))
                                .tracking(2.5)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(c.positiveMessage)
                                .font(SFont.display(18, weight: .light))
                                .foregroundStyle(.white)
                                .lineSpacing(5)
                            HStack(spacing: 6) {
                                Text(c.verticalType.uppercased())
                                    .font(SFont.label(10))
                                    .tracking(2)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.08))
                                    .clipShape(Capsule())
                                if c.isPetite {
                                    Text("PETITE")
                                        .font(SFont.label(10))
                                        .tracking(2)
                                        .foregroundStyle(.white.opacity(0.75))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                            if let note = c.petiteStylingNote {
                                Text(note)
                                    .font(SFont.body(12))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(SSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.09))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                    }

                    // Body measurements
                    if let m = item.bodyMeasurements {
                        VStack(alignment: .leading, spacing: SSpacing.md) {
                            Text("BODY PROFILE")
                                .font(SFont.label(11))
                                .tracking(3)
                                .foregroundStyle(Color("sTertiary"))

                            VStack(spacing: 1) {
                                DataRow(label: "Shoulder", value: m.shoulder)
                                DataRow(label: "Hip", value: m.hip)
                                DataRow(label: "Waist", value: m.waist)
                                DataRow(label: "Torso height", value: m.torsoHeight)
                                DataRow(label: "Leg length", value: m.legLength)
                            }
                            .background(Color("sSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            .softShadow()
                        }
                    }

                    // Garments
                    if !item.garments.isEmpty {
                        VStack(alignment: .leading, spacing: SSpacing.md) {
                            Text("GARMENTS (\(item.garments.count))")
                                .font(SFont.label(11))
                                .tracking(3)
                                .foregroundStyle(Color("sTertiary"))

                            VStack(spacing: SSpacing.md) {
                                ForEach(item.garments) { g in
                                    GarmentCard(garment: g)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: SSpacing.xxl)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, 48)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Pieces

private struct DataRow: View {
    let label: String
    let value: Double
    var body: some View {
        HStack {
            Text(label)
                .font(SFont.body(15))
                .foregroundStyle(Color("sSecondary"))
            Spacer()
            Text(String(format: "%.1f", value))
                .font(SFont.mono(15))
                .foregroundStyle(Color("sPrimary"))
            Text("cm")
                .font(SFont.body(12))
                .foregroundStyle(Color("sTertiary"))
        }
        .padding(.horizontal, SSpacing.md)
        .padding(.vertical, SSpacing.sm + 2)
        .background(Color("sSurface"))
    }
}

private struct GarmentCard: View {
    let garment: ScanHistoryItem.GarmentDTO

    var body: some View {
        VStack(alignment: .leading, spacing: SSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(garment.category.uppercased())
                    .font(SFont.label(11))
                    .tracking(2.5)
                    .foregroundStyle(Color("sPrimary"))
                Spacer()
                Text("\(Int(garment.classificationConfidence * 100))%")
                    .font(SFont.mono(11))
                    .foregroundStyle(Color("sTertiary"))
            }

            Text(garment.subcategory)
                .font(SFont.display(17, weight: .light))
                .foregroundStyle(Color("sPrimary"))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: SSpacing.xs
            ) {
                TagTile(label: "Pattern", value: garment.pattern)
                TagTile(label: "Silhouette", value: garment.silhouette)
                TagTile(label: "Length", value: garment.garmentLength)
                TagTile(label: "Weight", value: garment.visualWeight)
                if let n = garment.neckline, n != "Unknown" {
                    TagTile(label: "Neckline", value: n)
                }
                if let s = garment.sleeveLength, s != "Unknown" {
                    TagTile(label: "Sleeve", value: s)
                }
            }

            if !garment.primaryColors.isEmpty {
                HStack(spacing: SSpacing.sm) {
                    ForEach(garment.primaryColors, id: \.self) { hex in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorFromHex(hex))
                                .frame(width: 10, height: 10)
                            Text(hex)
                                .font(SFont.label(11))
                                .foregroundStyle(Color("sSecondary"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("sBackground"))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(SSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
        .softShadow()
    }

    private func colorFromHex(_ hex: String) -> Color {
        guard hex.hasPrefix("#"), hex.count == 7,
              let value = Int(hex.dropFirst(), radix: 16) else { return .gray }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

private struct TagTile: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(SFont.label(9))
                .tracking(1.5)
                .foregroundStyle(Color("sTertiary"))
            Text(value)
                .font(SFont.heading(13))
                .foregroundStyle(Color("sPrimary"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
