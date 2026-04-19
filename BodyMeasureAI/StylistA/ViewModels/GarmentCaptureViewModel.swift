//
//  GarmentCaptureViewModel.swift
//  BodyMeasureAI
//
//  Manages garment photo capture (camera or library) and analysis pipeline.
//

import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class GarmentCaptureViewModel: ObservableObject {

    @Published var selectedImage: UIImage?
    @Published var analysisResult: GarmentTagModel?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    private let classifier = GarmentClassifierService()

    /// Run color extraction + classifier, combine into GarmentTagModel, publish result.
    func analyzeGarment(image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil
        defer { isAnalyzing = false }

        AppLog.classification.info(
            "garment classify start size=\(Int(image.size.width))×\(Int(image.size.height))"
        )
        let start = CFAbsoluteTimeGetCurrent()
        let result = await classifier.classify(image: image)
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        AppLog.classification.info(
            "garment classify done (\(durationMs)ms) category=\(result.category.rawValue, privacy: .public) conf=\(result.classificationConfidence, format: .fixed(precision: 2), privacy: .public)"
        )
        analysisResult = result
    }

    func clearSelection() {
        selectedImage = nil
        analysisResult = nil
        errorMessage = nil
    }

    func setSelectedImage(_ image: UIImage?) {
        selectedImage = image
        analysisResult = nil
        errorMessage = nil
    }
}
