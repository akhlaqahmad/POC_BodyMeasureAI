//
//  BodyScanDetailView.swift
//  BodyMeasureAI
//
//  Read-only detail view for a past body scan from history.
//

import SwiftUI

struct BodyScanDetailView: View {
    let item: BodyScanHistoryItem
    @State private var appeared = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    /// Parsed measurements from JSON.
    private var measurements: [String: Double] {
        guard let data = item.measurementsJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else {
            return [:]
        }
        return json
    }

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: SSpacing.lg) {
                    // Snapshot image
                    snapshotImage
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5), value: appeared)

                    // Date & info
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        Text(dateFormatter.string(from: item.scanTimestamp))
                            .font(SFont.label(12))
                            .foregroundStyle(Color("sTertiary"))

                        Text(item.positiveMessage)
                            .font(SFont.body(16))
                            .foregroundStyle(Color("sPrimary"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SSpacing.lg)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                    // Info pills
                    HStack(spacing: SSpacing.sm) {
                        infoPill("HEIGHT", "\(Int(item.heightCm)) cm")
                        infoPill("GENDER", item.gender.capitalized)
                        infoPill("TYPE", item.verticalType.capitalized)
                        if item.isPetite { infoPill("", "Petite") }
                    }
                    .padding(.horizontal, SSpacing.lg)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                    // Measurement tiles
                    measurementGrid
                        .padding(.horizontal, SSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                    // Confidence
                    HStack {
                        Text("CONFIDENCE")
                            .font(SFont.label(11))
                            .tracking(2)
                            .foregroundStyle(Color("sTertiary"))
                        Spacer()
                        Text("\(Int(item.captureConfidence * 100))%")
                            .font(SFont.mono(20))
                            .foregroundStyle(Color("sSuccess"))
                    }
                    .padding(SSpacing.md)
                    .background(Color("sSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                    .padding(.horizontal, SSpacing.lg)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                    Spacer().frame(height: SSpacing.xxl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appeared = true }
    }

    // MARK: - Snapshot

    @ViewBuilder
    private var snapshotImage: some View {
        if let filename = item.imageLocalFilename,
           let image = ImageStorageService.shared.loadLocalImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.md)
        } else {
            RoundedRectangle(cornerRadius: SRadius.md)
                .fill(Color("sSurfaceElevated"))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: SSpacing.sm) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 40, weight: .thin))
                        Text("No snapshot")
                            .font(SFont.label(12))
                    }
                    .foregroundStyle(Color("sTertiary"))
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.md)
        }
    }

    // MARK: - Measurement Grid

    private var measurementGrid: some View {
        let tiles: [(String, String, String)] = [
            ("M1", "Shoulder", "M1_shoulderCircumferenceCm"),
            ("M2", "Hip", "M2_hipCircumferenceCm"),
            ("M3", "Waist", "M3_waistCircumferenceCm"),
            ("V1", "Torso", "V1_torsoHeightCm"),
            ("V2", "Legs", "V2_legLengthCm")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SSpacing.md) {
            ForEach(tiles, id: \.0) { code, label, key in
                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    Text(code)
                        .font(SFont.label(11))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    Text(String(format: "%.1f cm", measurements[key] ?? 0))
                        .font(SFont.mono(20))
                        .foregroundStyle(Color("sPrimary"))
                    Text(label)
                        .font(SFont.body(12))
                        .foregroundStyle(Color("sSecondary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SSpacing.md)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
            }
        }
    }

    // MARK: - Helpers

    private func infoPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            if !label.isEmpty {
                Text(label)
                    .font(SFont.label(9))
                    .tracking(1)
                    .foregroundStyle(Color("sTertiary"))
            }
            Text(value)
                .font(SFont.label(12))
                .foregroundStyle(Color("sPrimary"))
        }
        .padding(.horizontal, SSpacing.sm)
        .padding(.vertical, SSpacing.xs)
        .background(Color("sSurfaceElevated"))
        .clipShape(Capsule())
    }
}
