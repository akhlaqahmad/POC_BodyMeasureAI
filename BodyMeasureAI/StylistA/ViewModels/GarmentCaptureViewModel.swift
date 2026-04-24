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
import os

@MainActor
final class GarmentCaptureViewModel: ObservableObject {

    @Published var selectedImage: UIImage?
    @Published var analysisResult: GarmentTagModel?
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    /// When true, the next `analyzeGarment` call also runs the measurement
    /// service and, if a body scan is available, a fit comparison.
    @Published var measureGarmentBeta: Bool = false
    /// Non-fatal measurement feedback for the UI (e.g. "move the card closer").
    @Published var measurementNote: String?

    private let classifier = GarmentClassifierService()
    private let measurementService = GarmentMeasurementService()
    private let fitService = GarmentFitComparisonService()

    /// Run color extraction + classifier, combine into GarmentTagModel, publish result.
    /// When `measureGarmentBeta` is on and a body scan result is provided,
    /// the method additionally runs the reference-card measurement pipeline
    /// and fit comparison and attaches them to the result.
    func analyzeGarment(image: UIImage, body: BodyScanResult? = nil) async {
        isAnalyzing = true
        errorMessage = nil
        measurementNote = nil
        analysisResult = nil
        defer { isAnalyzing = false }

        AppLog.classification.info(
            "garment classify start size=\(Int(image.size.width))×\(Int(image.size.height))"
        )
        let start = CFAbsoluteTimeGetCurrent()
        var result = await classifier.classify(image: image)
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        AppLog.classification.info(
            "garment classify done (\(durationMs)ms) category=\(result.category.rawValue, privacy: .public) conf=\(result.classificationConfidence, format: .fixed(precision: 2), privacy: .public)"
        )

        if measureGarmentBeta {
            let measurementResult = await measurementService.measure(image: image)
            if let m = measurementResult.measurements {
                result.measurements = m
                if let body = body {
                    result.fitAssessment = fitService.compare(
                        garmentMeasurements: m,
                        body: body.measurements
                    )
                }
            } else {
                measurementNote = measurementResult.error
            }
        }

        analysisResult = result
    }

    func clearSelection() {
        selectedImage = nil
        analysisResult = nil
        errorMessage = nil
        measurementNote = nil
    }

    func setSelectedImage(_ image: UIImage?) {
        selectedImage = image
        analysisResult = nil
        errorMessage = nil
        measurementNote = nil
    }
}
