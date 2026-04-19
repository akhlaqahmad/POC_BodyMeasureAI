//
//  FinalScanResultView.swift
//  BodyMeasureAI
//
//  Combined results: summary, body table, positive message, garment tags, full JSON, Share/Copy, New Scan.
//

import SwiftUI
import UIKit

struct FinalScanResultView: View {
    let session: ScanSessionModel
    let onNewScan: () -> Void
    /// Optional coordinator hook so the view can trigger and observe uploads.
    /// Kept optional to avoid breaking existing call sites / previews.
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var appeared = false
    @State private var jsonExpanded = false

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SSpacing.xxl) {

                    // Header
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        HStack {
                            Text("STYLISTA")
                                .font(SFont.label(11))
                                .tracking(6)
                                .foregroundStyle(Color("sTertiary"))
                            Spacer()
                            SyncStatusBadge(status: coordinator.uploadStatus)
                        }
                        Text("Your Style\nProfile")
                            .font(SFont.display(40, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                            .lineSpacing(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.1),
                               value: appeared)

                    // Style insight card — inverted
                    VStack(alignment: .leading, spacing: SSpacing.sm) {
                        Text("STYLE INSIGHT")
                            .font(SFont.label(10))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(session.bodyClassification.positiveMessage)
                            .font(SFont.display(19, weight: .light))
                            .foregroundStyle(.white)
                            .lineSpacing(5)
                    }
                    .padding(SSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.2),
                               value: appeared)

                    // Body measurements
                    VStack(alignment: .leading, spacing: SSpacing.md) {
                        FinalSectionHeader(
                            title: "BODY PROFILE",
                            subtitle: "Circumference estimates")

                        VStack(spacing: 1) {
                            FinalDataRow(label: "Shoulder",
                                value: session.bodyMeasurements
                                    .m1ShoulderCircumferenceCm)
                            FinalDataRow(label: "Hip",
                                value: session.bodyMeasurements
                                    .m2HipCircumferenceCm)
                            FinalDataRow(label: "Waist",
                                value: session.bodyMeasurements
                                    .m3WaistCircumferenceCm)
                            FinalDataRow(label: "Torso height",
                                value: session.bodyMeasurements
                                    .v1TorsoHeightCm)
                            FinalDataRow(label: "Leg length",
                                value: session.bodyMeasurements
                                    .v2LegLengthCm)
                        }
                        .background(Color("sSurface"))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        .softShadow()
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3),
                               value: appeared)

                    // Garment profile
                    VStack(alignment: .leading, spacing: SSpacing.md) {
                        FinalSectionHeader(
                            title: "GARMENT PROFILE",
                            subtitle: session.garmentAnalysis.subcategory)

                        LazyVGrid(
                            columns: [GridItem(.flexible()),
                                      GridItem(.flexible())],
                            spacing: SSpacing.sm
                        ) {
                            FinalTagTile(label: "Category",
                                value: session.garmentAnalysis
                                    .category.rawValue)
                            FinalTagTile(label: "Silhouette",
                                value: session.garmentAnalysis
                                    .silhouette.rawValue)
                            FinalTagTile(label: "Length",
                                value: session.garmentAnalysis
                                    .garmentLength.rawValue)
                            FinalTagTile(label: "Visual Weight",
                                value: session.garmentAnalysis
                                    .visualWeight.rawValue)
                            if let n = session.garmentAnalysis.neckline,
                               n != .unknown {
                                FinalTagTile(label: "Neckline",
                                    value: n.rawValue)
                            }
                            if let s = session.garmentAnalysis.sleeveLength,
                               s != .unknown {
                                FinalTagTile(label: "Sleeve",
                                    value: s.rawValue)
                            }
                        }

                        // Colours (hex swatches ordered by coverage)
                        if !session.garmentAnalysis.primaryColors.isEmpty {
                            VStack(alignment: .leading, spacing: SSpacing.sm) {
                                Text("COLOURS (\(session.garmentAnalysis.primaryColors.count))")
                                    .font(SFont.label(9))
                                    .tracking(2)
                                    .foregroundStyle(Color("sTertiary"))
                                HStack(spacing: SSpacing.sm) {
                                    ForEach(
                                        session.garmentAnalysis.primaryColors,
                                        id: \.self
                                    ) { hex in
                                        let swatch = colorFromHex(hex)
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(swatch)
                                                .frame(width: 10, height: 10)
                                            Text(hex)
                                                .font(SFont.label(12))
                                                .foregroundStyle(Color("sPrimary"))
                                                .lineLimit(1)
                                                .fixedSize()
                                        }
                                        .padding(.horizontal, SSpacing.sm)
                                        .padding(.vertical, 5)
                                        .background(Color("sSurfaceElevated"))
                                        .clipShape(Capsule())
                                        .fixedSize()
                                    }
                                }
                            }
                            .padding(SSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color("sSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            .softShadow()
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4),
                               value: appeared)

                    // JSON (vertical only; no horizontal scrolling)
                    DisclosureGroup(isExpanded: $jsonExpanded) {
                        if let json = session.prettyPrintedJSON() {
                            ScrollView(.vertical, showsIndicators: true) {
                                Text(json)
                                    .font(SFont.mono(11))
                                    .foregroundStyle(Color("sSecondary"))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(SSpacing.md)
                            }
                            .frame(maxHeight: 260)
                            .background(Color("sSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
                        }
                    } label: {
                        Text("Raw JSON")
                            .font(SFont.label(13))
                            .tracking(0.5)
                            .foregroundStyle(Color("sTertiary"))
                    }

                    // Actions
                    VStack(spacing: SSpacing.sm) {
                        Button(action: shareJSON) {
                            HStack {
                                Text("Export Profile")
                                    .font(SFont.label(15))
                                    .tracking(0.5)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(Color("sBackground"))
                            .padding(SSpacing.md)
                            .background(Color("sAccent"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }

                        HStack(spacing: SSpacing.sm) {
                            Button(action: copyJSON) {
                                Text("Copy JSON")
                                    .font(SFont.label(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: SRadius.md))
                            }
                            Button(action: onNewScan) {
                                Text("New Scan")
                                    .font(SFont.label(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: SRadius.md))
                            }
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.5),
                               value: appeared)

                    Spacer().frame(height: SSpacing.xxl)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.xl)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            appeared = true
            AppLog.lifecycle.info("FinalScanResultView.onAppear sessionId=\(session.sessionId, privacy: .public)")
            coordinator.uploadCompletedSession(session)
        }
    }

    private struct FinalSectionHeader: View {
        let title: String
        let subtitle: String
        var body: some View {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(SFont.label(11))
                    .tracking(3)
                    .foregroundStyle(Color("sTertiary"))
                Spacer()
                Text(subtitle)
                    .font(SFont.body(13))
                    .foregroundStyle(Color("sSecondary"))
            }
        }
    }

    private struct FinalDataRow: View {
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

    private struct FinalTagTile: View {
        let label: String
        let value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(SFont.label(9))
                    .tracking(1.5)
                    .foregroundStyle(Color("sTertiary"))
                Text(value)
                    .font(SFont.heading(14))
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

    private func shareJSON() {
        let url = JSONExportService.exportJSON(session: session)
        presentShareSheet(items: [url])
    }

    private func copyJSON() {
        guard let json = session.prettyPrintedJSON() else { return }
        UIPasteboard.general.string = json
    }

    private func presentShareSheet(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    private func colorFromHex(_ hex: String) -> Color {
        guard hex.hasPrefix("#"), hex.count == 7,
              let value = Int(hex.dropFirst(), radix: 16) else { return Color.gray }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

/// Simple flow layout for tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(subviews: subviews, width: proposal.width ?? 0)
        return CGSize(width: result.width, height: result.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, width: bounds.width)
        for (i, subview) in subviews.enumerated() {
            guard i < result.frames.count else { break }
            let f = result.frames[i]
            subview.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY), anchor: .topLeading, proposal: ProposedViewSize(f.size))
        }
    }
    private func arrange(subviews: Subviews, width: CGFloat) -> (width: CGFloat, height: CGFloat, frames: [CGRect]) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (width, y + rowHeight, frames)
    }
}
