//
//  GarmentScanDetailView.swift
//  BodyMeasureAI
//
//  Read-only detail view for a past garment scan from history.
//

import SwiftUI

struct GarmentScanDetailView: View {
    let item: GarmentScanHistoryItem
    @State private var appeared = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    /// Parsed garment data from JSON.
    private var garmentData: [String: Any] {
        guard let data = item.garmentDataJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView {
                VStack(spacing: SSpacing.lg) {
                    // Garment image
                    garmentImage
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5), value: appeared)

                    // Date
                    Text(dateFormatter.string(from: item.scanTimestamp))
                        .font(SFont.label(12))
                        .foregroundStyle(Color("sTertiary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SSpacing.lg)

                    // Category header
                    Text(item.category)
                        .font(SFont.display(28, weight: .light))
                        .foregroundStyle(Color("sPrimary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                    // Tag grid
                    tagGrid
                        .padding(.horizontal, SSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 15)
                        .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                    // Color swatches
                    if !item.primaryColors.isEmpty {
                        VStack(alignment: .leading, spacing: SSpacing.sm) {
                            Text("COLORS")
                                .font(SFont.label(11))
                                .tracking(2)
                                .foregroundStyle(Color("sTertiary"))

                            HStack(spacing: SSpacing.sm) {
                                ForEach(item.primaryColors, id: \.self) { hex in
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 32, height: 32)
                                            .overlay(Circle().stroke(Color("sBorder"), lineWidth: 0.5))
                                        Text(hex)
                                            .font(SFont.mono(9))
                                            .foregroundStyle(Color("sTertiary"))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                    }

                    // Confidence
                    if let confidence = garmentData["classificationConfidence"] as? Double {
                        HStack {
                            Text("CONFIDENCE")
                                .font(SFont.label(11))
                                .tracking(2)
                                .foregroundStyle(Color("sTertiary"))
                            Spacer()
                            Text("\(Int(confidence * 100))%")
                                .font(SFont.mono(20))
                                .foregroundStyle(Color("sSuccess"))
                        }
                        .padding(SSpacing.md)
                        .background(Color("sSurface"))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        .padding(.horizontal, SSpacing.lg)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)
                    }

                    Spacer().frame(height: SSpacing.xxl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appeared = true }
    }

    // MARK: - Garment Image

    @ViewBuilder
    private var garmentImage: some View {
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
                        Image(systemName: "tshirt")
                            .font(.system(size: 40, weight: .thin))
                        Text("No image")
                            .font(SFont.label(12))
                    }
                    .foregroundStyle(Color("sTertiary"))
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.md)
        }
    }

    // MARK: - Tag Grid

    private var tagGrid: some View {
        let tags: [(String, String?)] = [
            ("Subcategory", garmentData["subcategory"] as? String),
            ("Pattern", garmentData["pattern"] as? String),
            ("Silhouette", garmentData["silhouette"] as? String),
            ("Length", garmentData["garmentLength"] as? String),
            ("Visual Weight", garmentData["visualWeight"] as? String),
            ("Neckline", garmentData["neckline"] as? String),
            ("Sleeve", garmentData["sleeveLength"] as? String)
        ]

        let validTags = tags.compactMap { label, value -> (String, String)? in
            guard let v = value, v != "Unknown" else { return nil }
            return (label, v)
        }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SSpacing.md) {
            ForEach(validTags, id: \.0) { label, value in
                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    Text(label.uppercased())
                        .font(SFont.label(10))
                        .tracking(1.5)
                        .foregroundStyle(Color("sTertiary"))
                    Text(value)
                        .font(SFont.heading(15))
                        .foregroundStyle(Color("sPrimary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SSpacing.md)
                .background(Color("sSurface"))
                .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
            }
        }
    }
}
