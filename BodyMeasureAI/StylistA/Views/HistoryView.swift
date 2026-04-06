//
//  HistoryView.swift
//  BodyMeasureAI
//
//  Tab-based scan history: Body Scans | Garment Scans.
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = HistoryViewModel()
    @State private var appeared = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("SCAN HISTORY")
                        .font(SFont.label(13))
                        .tracking(6)
                        .foregroundStyle(Color("sPrimary"))
                    Spacer()
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.lg)
                .padding(.bottom, SSpacing.md)

                // Tab picker
                Picker("", selection: $viewModel.selectedTab) {
                    ForEach(HistoryViewModel.HistoryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SSpacing.lg)
                .padding(.bottom, SSpacing.md)

                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color("sAccent"))
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: SSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(Color("sError"))
                        Text(error)
                            .font(SFont.body(14))
                            .foregroundStyle(Color("sSecondary"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(SSpacing.lg)
                    Spacer()
                } else {
                    switch viewModel.selectedTab {
                    case .body:
                        bodyScansTab
                    case .garment:
                        garmentScansTab
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadHistory()
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    // MARK: - Body Scans Tab

    @ViewBuilder
    private var bodyScansTab: some View {
        if viewModel.bodyScans.isEmpty {
            emptyState(icon: "figure.stand", message: "No body scans yet")
        } else {
            ScrollView {
                LazyVStack(spacing: SSpacing.md) {
                    ForEach(Array(viewModel.bodyScans.enumerated()), id: \.element.id) { index, item in
                        Button {
                            coordinator.openBodyScanDetail(item)
                        } label: {
                            bodyScanCard(item)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: appeared)
                    }
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.bottom, SSpacing.xxl)
            }
        }
    }

    private func bodyScanCard(_ item: BodyScanHistoryItem) -> some View {
        HStack(spacing: SSpacing.md) {
            // Thumbnail
            scanThumbnail(filename: item.imageLocalFilename, icon: "figure.stand")

            // Info
            VStack(alignment: .leading, spacing: SSpacing.xs) {
                Text(dateFormatter.string(from: item.scanTimestamp))
                    .font(SFont.label(12))
                    .foregroundStyle(Color("sTertiary"))

                Text(item.positiveMessage)
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sPrimary"))
                    .lineLimit(2)

                HStack(spacing: SSpacing.sm) {
                    tagPill(item.verticalType.capitalized)
                    tagPill("\(Int(item.captureConfidence * 100))%")
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color("sTertiary"))
        }
        .padding(SSpacing.md)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .softShadow()
    }

    // MARK: - Garment Scans Tab

    @ViewBuilder
    private var garmentScansTab: some View {
        if viewModel.garmentScans.isEmpty {
            emptyState(icon: "tshirt", message: "No garment scans yet")
        } else {
            ScrollView {
                LazyVStack(spacing: SSpacing.md) {
                    ForEach(Array(viewModel.garmentScans.enumerated()), id: \.element.id) { index, item in
                        Button {
                            coordinator.openGarmentScanDetail(item)
                        } label: {
                            garmentScanCard(item)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: appeared)
                    }
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.bottom, SSpacing.xxl)
            }
        }
    }

    private func garmentScanCard(_ item: GarmentScanHistoryItem) -> some View {
        HStack(spacing: SSpacing.md) {
            // Thumbnail
            scanThumbnail(filename: item.imageLocalFilename, icon: "tshirt")

            // Info
            VStack(alignment: .leading, spacing: SSpacing.xs) {
                Text(dateFormatter.string(from: item.scanTimestamp))
                    .font(SFont.label(12))
                    .foregroundStyle(Color("sTertiary"))

                Text(item.category)
                    .font(SFont.heading(16))
                    .foregroundStyle(Color("sPrimary"))

                // Color swatches
                if !item.primaryColors.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.primaryColors.prefix(5), id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color("sBorder"), lineWidth: 0.5))
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color("sTertiary"))
        }
        .padding(SSpacing.md)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .softShadow()
    }

    // MARK: - Shared Components

    private func scanThumbnail(filename: String?, icon: String) -> some View {
        Group {
            if let filename, let thumb = ImageStorageService.shared.loadThumbnail(filename: filename) {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color("sTertiary"))
            }
        }
        .frame(width: 60, height: 60)
        .background(Color("sSurfaceElevated"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
    }

    private func tagPill(_ text: String) -> some View {
        Text(text)
            .font(SFont.label(10))
            .foregroundStyle(Color("sSecondary"))
            .padding(.horizontal, SSpacing.sm)
            .padding(.vertical, 3)
            .background(Color("sSurfaceElevated"))
            .clipShape(Capsule())
    }

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: SSpacing.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(Color("sTertiary"))
            Text(message)
                .font(SFont.body(16))
                .foregroundStyle(Color("sSecondary"))
            Spacer()
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
