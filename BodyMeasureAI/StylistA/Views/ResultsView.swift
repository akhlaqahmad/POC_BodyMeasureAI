//
//  ResultsView.swift
//  BodyMeasureAI
//
//  Part 1: measurements display, positive message, Export + Scan Again.
//

import SwiftUI
import UIKit

struct ResultsView: View {
    let result: BodyScanResult
    let onScanAgain: () -> Void
    let onContinueToGarment: () -> Void
    let onValidationMode: () -> Void
    let onStartMultiAngleScan: () -> Void

    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var appeared = false
    @State private var selectedAngleIndex: Int = 0
    @State private var jsonExpanded: Bool = false
    @State private var showJSONSheet: Bool = false

    /// Resolves font ambiguity when using SFont with .font() modifier.
    private func f(_ size: CGFloat) -> Font { SFont.label(size) }
    private func fDisplay(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        SFont.display(size, weight: weight)
    }
    private func fMono(_ size: CGFloat) -> Font { SFont.mono(size) }
    private func fBody(_ size: CGFloat) -> Font { SFont.body(size) }

    fileprivate static func fontLabel(_ size: CGFloat) -> Font { SFont.label(size) }
    fileprivate static func fontMono(_ size: CGFloat) -> Font { SFont.mono(size) }
    fileprivate static func fontBody(_ size: CGFloat) -> Font { SFont.body(size) }

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SSpacing.xl) {

                    // Header
                    VStack(alignment: .leading, spacing: SSpacing.xs) {
                        HStack {
                            Text("SCAN RESULTS")
                                .font(f(11))
                                .tracking(3)
                                .foregroundStyle(Color("sTertiary"))
                            Spacer()
                            SyncStatusBadge(status: coordinator.uploadStatus)
                        }
                        Text("Body Profile")
                            .font(fDisplay(34, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.1),
                               value: appeared)

                    // Positive message
                    VStack(alignment: .leading, spacing: SSpacing.sm) {
                        Text("\"")
                            .font(fDisplay(48, weight: .light))
                            .foregroundStyle(Color("sAccent").opacity(0.25))
                            .offset(y: 8)
                        Text(result.positiveMessage)
                            .font(fDisplay(20, weight: .light))
                            .foregroundStyle(Color("sPrimary"))
                            .lineSpacing(6)
                    }
                    .padding(SSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("sSurface"))
                    .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                    .softShadow()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.2),
                               value: appeared)

                    // Measurements
                    VStack(alignment: .leading, spacing: SSpacing.md) {
                        Text("MEASUREMENTS")
                            .font(f(11))
                            .tracking(3)
                            .foregroundStyle(Color("sTertiary"))

                        if result.multiAngleMeasurements != nil {
                            Picker("", selection: $selectedAngleIndex) {
                                Text("Front").tag(0)
                                Text("Side").tag(1)
                                Text("Back").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .tint(.black)
                        }

                        HStack(spacing: SSpacing.sm) {
                            MeasurementTile(label: "SHOULDER",
                                value: displayedMeasurements.m1ShoulderCircumferenceCm)
                            MeasurementTile(label: "HIP",
                                value: displayedMeasurements.m2HipCircumferenceCm)
                            MeasurementTile(label: "WAIST",
                                value: displayedMeasurements.m3WaistCircumferenceCm)
                        }

                        HStack(spacing: SSpacing.sm) {
                            MeasurementTile(label: "TORSO",
                                value: displayedMeasurements.v1TorsoHeightCm)
                            MeasurementTile(label: "LEGS",
                                value: displayedMeasurements.v2LegLengthCm)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CONFIDENCE")
                                    .font(f(9))
                                    .tracking(1.5)
                                    .foregroundStyle(Color("sTertiary"))
                                Spacer()
                                Text("\(Int(displayedMeasurements.captureConfidence * 100))%")
                                    .font(fMono(26))
                                    .foregroundStyle(Color("sSuccess"))
                            }
                            .padding(SSpacing.md)
                            .frame(maxWidth: .infinity,
                                   minHeight: 90,
                                   alignment: .leading)
                            .background(Color("sSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            .softShadow()
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.3),
                               value: appeared)

                    // Actions
                    VStack(spacing: SSpacing.sm) {
                        Button(action: onStartMultiAngleScan) {
                            HStack {
                                Text("3-Angle Scan (beta)")
                                    .font(f(13))
                                    .tracking(0.5)
                                Spacer()
                                Image(systemName: "person.3.sequence")
                                    .font(Font.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color("sPrimary"))
                            .padding(SSpacing.md)
                            .background(Color("sSurfaceElevated"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }

                        Button(action: onContinueToGarment) {
                            HStack {
                                Text("Analyse Garment")
                                    .font(f(15))
                                    .tracking(0.5)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(Font.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color("sBackground"))
                            .padding(SSpacing.md)
                            .background(Color("sAccent"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }

                        HStack(spacing: SSpacing.sm) {
                            Button(action: onScanAgain) {
                                Text("Scan Again")
                                    .font(f(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: SRadius.md))
                            }
                            Button(action: { exportJSON() }) {
                                Text("Export")
                                    .font(f(14))
                                    .foregroundStyle(Color("sPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, SSpacing.md)
                                    .background(Color("sSurfaceElevated"))
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: SRadius.md))
                            }
                        }
                        
                        Button(action: { showJSONSheet = true }) {
                            HStack {
                                Text("View JSON Result")
                                    .font(f(14))
                                Spacer()
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(Font.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color("sPrimary"))
                            .padding(.vertical, SSpacing.md)
                            .padding(.horizontal, SSpacing.md)
                            .background(Color("sSurfaceElevated"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }
                        Button(action: { copyJSON() }) {
                            Text("Copy JSON")
                                .font(f(14))
                                .foregroundStyle(Color("sPrimary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, SSpacing.md)
                                .background(Color("sSurfaceElevated"))
                                .clipShape(RoundedRectangle(
                                    cornerRadius: SRadius.md))
                        }

                        Button(action: onValidationMode) {
                            Text("Validation Mode")
                                .font(f(12))
                                .tracking(0.5)
                                .foregroundStyle(Color("sTertiary"))
                        }
                        .padding(.top, SSpacing.xs)
                    }
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4),
                               value: appeared)

                    // Raw JSON (expandable)
                    DisclosureGroup(isExpanded: $jsonExpanded) {
                        if let json = result.prettyPrintedJSON() {
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
                            .font(f(13))
                            .tracking(0.5)
                            .foregroundStyle(Color("sTertiary"))
                    }

                    Spacer().frame(height: SSpacing.xxl)
                }
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.xl)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            appeared = true
            AppLog.lifecycle.info("ResultsView.onAppear")
            coordinator.uploadBodyOnlyIfNeeded(result)
        }
        .sheet(isPresented: $showJSONSheet) {
            NavigationStack {
                ZStack {
                    Color("sBackground").ignoresSafeArea()
                    ScrollView {
                        Text(result.prettyPrintedJSON() ?? "{}")
                            .font(SFont.mono(12))
                            .foregroundStyle(Color("sSecondary"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SSpacing.md)
                            .background(Color("sSurface"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                            .softShadow()
                            .padding(SSpacing.lg)
                    }
                }
                .navigationTitle("JSON Result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { showJSONSheet = false }
                            .font(SFont.label(14))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Copy") { copyJSON() }
                            .font(SFont.label(14))
                    }
                }
            }
        }
    }

    private func exportJSON() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { return }
        guard let json = result.prettyPrintedJSON(),
              let data = json.data(using: .utf8) else { return }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("body-scan.json")
        try? data.write(to: temp)
        let vc = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    private func copyJSON() {
        guard let json = result.prettyPrintedJSON() else { return }
        UIPasteboard.general.string = json
    }
}

private extension ResultsView {
    var displayedMeasurements: BodyProportionModel {
        guard let angles = result.multiAngleMeasurements else { return result.measurements }
        switch selectedAngleIndex {
        case 1: return angles.side
        case 2: return angles.back ?? angles.front
        default: return angles.front
        }
    }
}

private struct MeasurementTile: View {
    let label: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ResultsView.fontLabel(9))
                .tracking(1.5)
                .foregroundStyle(Color("sTertiary"))
            Spacer()
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(ResultsView.fontMono(22))
                    .foregroundStyle(Color("sPrimary"))
                Text("cm")
                    .font(ResultsView.fontBody(11))
                    .foregroundStyle(Color("sTertiary"))
            }
        }
        .padding(SSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .background(Color("sSurface"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
        .softShadow()
    }
}
