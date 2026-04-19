//
//  ScanHistoryView.swift
//  BodyMeasureAI
//
//  Lists this device's previous scans fetched from the backend. Each row
//  shows body measurement summary + garment tags. Tapping opens the detail.
//

import SwiftUI

@MainActor
final class ScanHistoryViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded([ScanHistoryItem])
        case failed(String)
    }

    @Published var state: State = .idle

    func load() async {
        state = .loading
        AppLog.network.info("ScanHistory load()")
        let result = await BackendAPIClient.fetchHistory()
        switch result {
        case .success(let items):
            state = .loaded(items)
        case .failure(let err):
            state = .failed("\(err)")
        }
    }
}

struct ScanHistoryView: View {
    let onOpenDetail: (ScanHistoryItem) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = ScanHistoryViewModel()

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("sPrimary"))
                            .frame(width: 36, height: 36)
                            .background(Color("sSurface"))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("PREVIOUS SCANS")
                        .font(SFont.label(11))
                        .tracking(3)
                        .foregroundStyle(Color("sTertiary"))
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, 48)
                .padding(.bottom, SSpacing.lg)

                content
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
            if case .loaded(let items) = viewModel.state {
                coordinator.historyItems = items
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: SSpacing.sm) {
                ProgressView().tint(Color("sPrimary"))
                Text("Loading…")
                    .font(SFont.label(12))
                    .tracking(2)
                    .foregroundStyle(Color("sTertiary"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: SSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundStyle(Color("sTertiary"))
                Text("Couldn't load history")
                    .font(SFont.display(18, weight: .light))
                Text(message)
                    .font(SFont.body(12))
                    .foregroundStyle(Color("sSecondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SSpacing.xl)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .font(SFont.label(14))
                .foregroundStyle(Color("sPrimary"))
                .padding(.horizontal, SSpacing.lg)
                .padding(.vertical, SSpacing.sm)
                .background(Color("sSurface"))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let items) where items.isEmpty:
            VStack(spacing: SSpacing.md) {
                Image(systemName: "tray")
                    .font(.system(size: 28))
                    .foregroundStyle(Color("sTertiary"))
                Text("No scans yet")
                    .font(SFont.display(20, weight: .light))
                Text("Complete a scan and it'll appear here.")
                    .font(SFont.body(13))
                    .foregroundStyle(Color("sSecondary"))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let items):
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: SSpacing.md) {
                    ForEach(items) { item in
                        Button { onOpenDetail(item) } label: {
                            ScanHistoryRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(height: SSpacing.xl)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.sm)
            }
        }
    }
}

// MARK: - Row

private struct ScanHistoryRow: View {
    let item: ScanHistoryItem

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: SSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.dateFormatter.string(from: item.scanTimestamp))
                    .font(SFont.label(13))
                    .tracking(1)
                    .foregroundStyle(Color("sPrimary"))
                Spacer()
                Text("\(Int(item.captureConfidence * 100))%")
                    .font(SFont.mono(12))
                    .foregroundStyle(Color("sTertiary"))
            }

            if let c = item.bodyClassification {
                HStack(spacing: 6) {
                    Text(c.verticalType.uppercased())
                        .font(SFont.label(10))
                        .tracking(2)
                        .foregroundStyle(Color("sSecondary"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("sBackground"))
                        .clipShape(Capsule())
                    if c.isPetite {
                        Text("PETITE")
                            .font(SFont.label(10))
                            .tracking(2)
                            .foregroundStyle(Color("sSecondary"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color("sBackground"))
                            .clipShape(Capsule())
                    }
                }
            }

            if let m = item.bodyMeasurements {
                HStack(spacing: SSpacing.sm) {
                    MeasurementChip(label: "SH", value: m.shoulder)
                    MeasurementChip(label: "HP", value: m.hip)
                    MeasurementChip(label: "WT", value: m.waist)
                    MeasurementChip(label: "TR", value: m.torsoHeight)
                    MeasurementChip(label: "LG", value: m.legLength)
                }
            }

            if !item.garments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GARMENTS (\(item.garments.count))")
                        .font(SFont.label(9))
                        .tracking(2)
                        .foregroundStyle(Color("sTertiary"))
                    ForEach(item.garments) { g in
                        HStack(spacing: 6) {
                            Text(g.category.uppercased())
                                .font(SFont.label(10))
                                .tracking(1.5)
                                .foregroundStyle(Color("sPrimary"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color("sBackground"))
                                .clipShape(Capsule())
                            Text(g.subcategory)
                                .font(SFont.body(12))
                                .foregroundStyle(Color("sSecondary"))
                                .lineLimit(1)
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(Array(g.primaryColors.prefix(3)), id: \.self) { hex in
                                    Circle()
                                        .fill(colorFromHex(hex))
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
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

private struct MeasurementChip: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(SFont.label(8))
                .tracking(1.5)
                .foregroundStyle(Color("sTertiary"))
            Text(String(format: "%.0f", value))
                .font(SFont.mono(13))
                .foregroundStyle(Color("sPrimary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
