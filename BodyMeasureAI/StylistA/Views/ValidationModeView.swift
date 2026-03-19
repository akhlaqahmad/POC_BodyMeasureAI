//
//  ValidationModeView.swift
//  BodyMeasureAI
//
//  Accuracy test: estimated vs manual for M1–M3, V1–V2. Thresholds: ±5 cm (circumference), ±3 cm (length).
//

import SwiftUI
import UIKit

struct ValidationModeView: View {
    let bodyResult: BodyScanResult
    let onDismiss: () -> Void

    private static let circumferenceThreshold = 5.0
    private static let lengthThreshold = 3.0

    @State private var manualM1: String = ""
    @State private var manualM2: String = ""
    @State private var manualM3: String = ""
    @State private var manualV1: String = ""
    @State private var manualV2: String = ""

    private var entries: [ValidationEntry] {
        let m = bodyResult.measurements
        return [
            entry("M1_ShoulderCirc", m.m1ShoulderCircumferenceCm, manualM1, Self.circumferenceThreshold),
            entry("M2_HipCirc", m.m2HipCircumferenceCm, manualM2, Self.circumferenceThreshold),
            entry("M3_WaistCirc", m.m3WaistCircumferenceCm, manualM3, Self.circumferenceThreshold),
            entry("V1_Torso", m.v1TorsoHeightCm, manualV1, Self.lengthThreshold),
            entry("V2_Legs", m.v2LegLengthCm, manualV2, Self.lengthThreshold)
        ]
    }

    private func entry(_ name: String, _ estimated: Double, _ manualStr: String, _ threshold: Double) -> ValidationEntry {
        let manual = Double(manualStr.trimmingCharacters(in: .whitespaces)) ?? 0
        let hasManual = !manualStr.trimmingCharacters(in: .whitespaces).isEmpty
        let err = hasManual ? abs(estimated - manual) : 0
        return ValidationEntry(
            measurement: name,
            estimatedCm: estimated,
            manualCm: manual,
            errorCm: err,
            pass: hasManual ? err <= threshold : false
        )
    }

    private var passCount: Int {
        entries.filter(\.pass).count
    }

    private var overallPass: Bool {
        passCount >= 4
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter manual tape measurements (cm) to compare with app estimates.")
                    .font(SFont.body(14))
                    .foregroundStyle(Color("sSecondary"))

                validationRow("M1 Shoulder Circ.", bodyResult.measurements.m1ShoulderCircumferenceCm, $manualM1, Self.circumferenceThreshold)
                validationRow("M2 Hip Circ.", bodyResult.measurements.m2HipCircumferenceCm, $manualM2, Self.circumferenceThreshold)
                validationRow("M3 Waist Circ.", bodyResult.measurements.m3WaistCircumferenceCm, $manualM3, Self.circumferenceThreshold)
                validationRow("V1 Torso", bodyResult.measurements.v1TorsoHeightCm, $manualV1, Self.lengthThreshold)
                validationRow("V2 Legs", bodyResult.measurements.v2LegLengthCm, $manualV2, Self.lengthThreshold)

                summarySection
                exportButton
                dismissButton
            }
            .padding()
        }
        .navigationTitle("Validation Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func validationRow(_ label: String, _ estimated: Double, _ manualBinding: Binding<String>, _ threshold: Double) -> some View {
        let manualStr = manualBinding.wrappedValue.trimmingCharacters(in: .whitespaces)
        let hasManual = !manualStr.isEmpty
        let manual = Double(manualStr) ?? 0
        let error = hasManual ? abs(estimated - manual) : 0
        let pass = hasManual && error <= threshold
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(SFont.heading(16))
            HStack {
                Text("Estimated: \(format(estimated)) cm")
                    .font(SFont.body(13))
                    .foregroundStyle(Color("sSecondary"))
                Spacer()
            }
            TextField("Manual measurement (cm)", text: manualBinding)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(SFont.body(15))
            HStack {
                Text(hasManual ? "Error: \(format(error)) cm" : "Error: —")
                    .font(SFont.label(12))
                Spacer()
                Text(hasManual ? (pass ? "PASS" : "FAIL") : "—")
                    .font(SFont.label(12))
                    .fontWeight(.semibold)
                    .foregroundStyle(hasManual ? (pass ? Color("sSuccess") : Color("sError")) : Color("sTertiary"))
            }
        }
        .padding()
        .background(pass ? Color("sSuccess").opacity(0.08) : (hasManual ? Color("sError").opacity(0.08) : Color("sSurface")))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(SFont.heading(16))
                .foregroundStyle(Color("sPrimary"))
            Text("\(passCount) of 5 measurements within threshold")
                .font(SFont.body(14))
                .foregroundStyle(Color("sSecondary"))
            Text(overallPass ? "Overall: PASS" : "Overall: FAIL")
                .font(SFont.heading(15))
                .fontWeight(.semibold)
                .foregroundStyle(overallPass ? Color("sSuccess") : Color("sError"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color("sSurfaceElevated"))
        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
    }

    private var exportButton: some View {
        Button("Export Validation Report") {
            let url = JSONExportService.exportCSV(results: entries)
            presentShareSheet(items: [url])
        }
        .font(SFont.label(15))
        .buttonStyle(.borderedProminent)
    }

    private var dismissButton: some View {
        Button("Done", action: onDismiss)
            .font(SFont.label(15))
            .buttonStyle(.bordered)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.1f", value)
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
}
