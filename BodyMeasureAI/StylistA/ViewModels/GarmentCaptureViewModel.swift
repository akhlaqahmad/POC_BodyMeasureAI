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

        let result = await classifier.classify(image: image)
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
