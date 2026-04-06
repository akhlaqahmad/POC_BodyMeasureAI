//
//  HistoryViewModel.swift
//  BodyMeasureAI
//
//  Manages loading and state for the scan history screen.
//

import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {

    enum HistoryTab: String, CaseIterable {
        case body = "Body Scans"
        case garment = "Garment Scans"
    }

    @Published var selectedTab: HistoryTab = .body
    @Published var bodyScans: [BodyScanHistoryItem] = []
    @Published var garmentScans: [GarmentScanHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadHistory() async {
        isLoading = true
        errorMessage = nil

        do {
            async let bodyFetch = ScanDatabaseService.shared.fetchBodyScans()
            async let garmentFetch = ScanDatabaseService.shared.fetchGarmentScans()

            let (body, garment) = try await (bodyFetch, garmentFetch)
            bodyScans = body
            garmentScans = garment
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
