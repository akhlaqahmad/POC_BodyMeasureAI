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
        Log.info("GarmentCaptureViewModel: analyzeGarment started")
        isAnalyzing = true
        errorMessage = nil
        analysisResult = nil
        defer { isAnalyzing = false }

        var result = await classifier.classify(image: image)

        // Save garment image locally and start background upload
        if let filename = ImageStorageService.shared.saveImageLocally(image: image, prefix: "garment") {
            result.imageLocalFilename = filename
            Task.detached {
                if let fileId = await ImageStorageService.shared.uploadToCloud(filename: filename) {
                    await MainActor.run {
                        result.imageRemoteFileId = fileId
                    }
                }
            }
        }

        analysisResult = result
        Log.info("GarmentCaptureViewModel: analyzeGarment completed", context: ["category": result.category.rawValue])
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
