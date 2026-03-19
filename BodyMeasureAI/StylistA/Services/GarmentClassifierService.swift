//
//  GarmentClassifierService.swift
//  BodyMeasureAI
//
//  Uses Vision (VNClassifyImageRequest) + heuristics to classify garment images.
//  Decoupled so CoreML model can be swapped later.
//

import Foundation
import Vision
import UIKit

final class GarmentClassifierService {

    private static let minConfidence: Double = 0.5
    private let colorExtractor = GarmentColorExtractor()

    /// Classify image: Vision labels + heuristics → GarmentTagModel.
    func classify(image: UIImage) async -> GarmentTagModel {
        let colorHexes = colorExtractor.extractDominantColorHexes(from: image)
        let (visionCategory, visionSubcategory, visionConfidence, observations) = await runVisionClassification(image: image)
        let (visualWeight, silhouette, garmentLength, neckline, sleeveLength, pattern) = computeHeuristics(
            image: image,
            primaryColorHexes: colorHexes,
            observations: observations
        )

        // POC: fallback must be Top / "Top", never Unknown or "Garment"
        let category = visionConfidence >= Self.minConfidence ? visionCategory : .top
        let subcategory = visionConfidence >= Self.minConfidence ? visionSubcategory : "Top"
        let confidence = visionConfidence

        return GarmentTagModel(
            category: category,
            subcategory: subcategory,
            primaryColors: Array(colorHexes.prefix(3)),
            pattern: pattern,
            silhouette: silhouette,
            neckline: category == .top || category == .dress ? neckline : nil,
            sleeveLength: category == .top || category == .dress ? sleeveLength : nil,
            garmentLength: garmentLength,
            visualWeight: visualWeight,
            classificationConfidence: confidence
        )
    }

    // MARK: - Vision

    private func runVisionClassification(image: UIImage) async -> (GarmentCategory, String, Double, [VNClassificationObservation]) {
        await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: (.unknown, "Unknown", 0, []))
                return
            }
            let request = VNClassifyImageRequest()
            request.revision = VNClassifyImageRequestRevision1
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let (category, subcategory, confidence) = mapObservationsToGarment(observations)
                continuation.resume(returning: (category, subcategory, confidence, observations))
            } catch {
                continuation.resume(returning: (.unknown, "Unknown", 0, []))
            }
        }
    }

    /// Map Vision classification identifiers to GarmentCategory and subcategory.
    private func mapObservationsToGarment(_ observations: [VNClassificationObservation]) -> (GarmentCategory, String, Double) {
        let top10 = observations.prefix(15)

        for obs in top10 {
            let id = obs.identifier.lowercased()
            let conf = Double(obs.confidence)
            if conf < Self.minConfidence { continue }

            // Dresses
            if id.contains("gown") || id.contains("evening gown") {
                return (.dress, "Gown", conf)
            }
            if id.contains("dress") || id.contains("frock") {
                return (.dress, "Dress", conf)
            }
            if id.contains("saree") || id.contains("sari") {
                return (.dress, "Saree", conf)
            }

            // Outerwear
            if id.contains("blazer") || id.contains("sport coat") {
                return (.outerwear, "Blazer", conf)
            }
            if id.contains("suit") && !id.contains("swimsuit") {
                return (.outerwear, "Suit", conf)
            }
            if id.contains("overcoat") || id.contains("trench") {
                return (.outerwear, "Coat", conf)
            }
            if id.contains("jacket") || id.contains("windbreaker") {
                return (.outerwear, "Jacket", conf)
            }
            if id.contains("cardigan") { return (.outerwear, "Cardigan", conf) }

            // Tops
            if id.contains("sweater") || id.contains("jumper") || id.contains("pullover") {
                return (.top, "Sweater", conf)
            }
            if id.contains("hoodie") || id.contains("sweatshirt") {
                return (.top, "Hoodie", conf)
            }
            if id.contains("polo") { return (.top, "Polo shirt", conf) }
            if id.contains("t-shirt") || id.contains("tee shirt") || id.contains("tee") {
                return (.top, "T-shirt", conf)
            }
            if id.contains("blouse") { return (.top, "Blouse", conf) }
            if id.contains("tunic") || id.contains("kurti") || id.contains("kurta") {
                return (.top, "Tunic", conf)
            }
            if id.contains("tank") || id.contains("singlet") || id.contains("camisole") {
                return (.top, "Tank top", conf)
            }
            if id.contains("shirt") { return (.top, "Shirt", conf) }
            if id.contains("crop") { return (.top, "Crop top", conf) }
            if id.contains("top") { return (.top, "Top", conf) }

            // Bottoms
            if id.contains("legging") { return (.bottom, "Leggings", conf) }
            if id.contains("jogger") { return (.bottom, "Joggers", conf) }
            if id.contains("jean") || id.contains("denim") {
                return (.bottom, "Jeans", conf)
            }
            if id.contains("trouser") || id.contains("pant") || id.contains("chino") {
                return (.bottom, "Trousers", conf)
            }
            if id.contains("short") && (id.contains("pant") || id.contains("bermuda")) {
                return (.bottom, "Shorts", conf)
            }
            if id.contains("skirt") || id.contains("pleated skirt") {
                return (.bottom, "Skirt", conf)
            }

            // Shoes
            if id.contains("sneaker") || id.contains("trainer") {
                return (.shoes, "Sneakers", conf)
            }
            if id.contains("boot") { return (.shoes, "Boots", conf) }
            if id.contains("heel") || id.contains("pump") || id.contains("stiletto") {
                return (.shoes, "Heels", conf)
            }
            if id.contains("sandal") || id.contains("flip flop") {
                return (.shoes, "Sandals", conf)
            }
            if id.contains("shoe") || id.contains("footwear") || id.contains("loafer") {
                return (.shoes, "Shoes", conf)
            }

            // Accessories
            if id.contains("scarf") || id.contains("shawl") {
                return (.accessory, "Scarf", conf)
            }
            if id.contains("hat") || id.contains("cap") || id.contains("beanie") {
                return (.accessory, "Hat", conf)
            }
            if id.contains("bag") || id.contains("handbag") || id.contains("purse") {
                return (.accessory, "Bag", conf)
            }
            if id.contains("belt") { return (.accessory, "Belt", conf) }
            if id.contains("watch") { return (.accessory, "Watch", conf) }
            if id.contains("sunglasses") || id.contains("glasses") {
                return (.accessory, "Glasses", conf)
            }

            // Generic cloth fallbacks → Top not "Garment"
            if id.contains("cloth") || id.contains("apparel") || id.contains("garment") ||
               id.contains("wear") || id.contains("textile") || id.contains("fabric") {
                return (.top, "Top", conf)
            }
        }

        let bestConf = top10.first.flatMap { Double($0.confidence) } ?? 0
        return (.top, "Top", bestConf * 0.5)
    }

    // MARK: - Heuristics (Vision labels + aspect ratio + color)

    private func computeHeuristics(
        image: UIImage,
        primaryColorHexes: [String],
        observations: [VNClassificationObservation]
    ) -> (VisualWeight, GarmentSilhouette, GarmentLength, NecklineType?, SleeveLength?, GarmentPattern) {
        let allIds = observations.prefix(20).map { $0.identifier.lowercased() }.joined(separator: " ")

        let aspectRatio = image.size.width > 0 ? image.size.height / image.size.width : 1.0
        let firstHex = primaryColorHexes.first
        let brightnessValue = brightness(from: firstHex)
        let isDark = brightnessValue < 0.35
        let isLight = brightnessValue > 0.75

        let visualWeight: VisualWeight
        if isDark { visualWeight = .heavy }
        else if isLight { visualWeight = .light }
        else { visualWeight = .medium }

        // Pattern from Vision labels when present
        let pattern: GarmentPattern
        if allIds.contains("striped") || allIds.contains("stripe") { pattern = .striped }
        else if allIds.contains("floral") || allIds.contains("flower") { pattern = .floral }
        else if allIds.contains("plaid") || allIds.contains("checked") || allIds.contains("tartan") { pattern = .checked }
        else if allIds.contains("geometric") || allIds.contains("pattern") { pattern = .geometric }
        else if allIds.contains("animal") || allIds.contains("leopard") || allIds.contains("zebra") { pattern = .animalPrint }
        else { pattern = .solid }

        // Silhouette from aspect ratio (proxy for drape/length)
        let silhouette: GarmentSilhouette
        if allIds.contains("tailored") || allIds.contains("fitted") { silhouette = .tailored }
        else if aspectRatio > 1.4 { silhouette = .flowing }
        else if aspectRatio > 1.15 { silhouette = .bodySkimming }
        else if aspectRatio < 0.85 || allIds.contains("oversized") { silhouette = .oversized }
        else { silhouette = .relaxed }

        // Garment length from aspect ratio
        let garmentLength: GarmentLength
        if allIds.contains("maxi") || allIds.contains("long dress") { garmentLength = .maxi }
        else if allIds.contains("midi") { garmentLength = .midi }
        else if allIds.contains("mini") || allIds.contains("short ") { garmentLength = .mini }
        else if allIds.contains("cropped") || allIds.contains("crop") { garmentLength = .cropped }
        else if aspectRatio > 1.5 { garmentLength = .maxi }
        else if aspectRatio > 1.2 { garmentLength = .midi }
        else if aspectRatio > 1.0 { garmentLength = .knee }
        else if aspectRatio < 0.7 { garmentLength = .cropped }
        else { garmentLength = .hipLength }

        // Neckline from Vision labels
        let neckline: NecklineType?
        if allIds.contains("v-neck") || allIds.contains("v neck") { neckline = .vNeck }
        else if allIds.contains("scoop") { neckline = .scoop }
        else if allIds.contains("boat") || allIds.contains("bateau") { neckline = .boat }
        else if allIds.contains("square neck") { neckline = .square }
        else if allIds.contains("halter") { neckline = .halter }
        else if allIds.contains("collar") || allIds.contains("collared") { neckline = .collared }
        else if allIds.contains("crew") || allIds.contains("round neck") { neckline = .crew }
        else { neckline = .crew }

        // Sleeve length from Vision labels
        let sleeveLength: SleeveLength?
        if allIds.contains("sleeveless") || allIds.contains("tank") || allIds.contains("camisole") { sleeveLength = .sleeveless }
        else if allIds.contains("cap sleeve") { sleeveLength = .cap }
        else if allIds.contains("short sleeve") || allIds.contains("short-sleeve") { sleeveLength = .short }
        else if allIds.contains("elbow") { sleeveLength = .elbow }
        else if allIds.contains("three-quarter") || allIds.contains("3/4") { sleeveLength = .threeQuarter }
        else if allIds.contains("long sleeve") || allIds.contains("long-sleeve") || allIds.contains("sleeve") { sleeveLength = .long }
        else { sleeveLength = .long }

        return (visualWeight, silhouette, garmentLength, neckline, sleeveLength, pattern)
    }

    /// Approximate brightness (luma) from first hex colour.
    private func brightness(from hex: String?) -> Double {
        guard let hex = hex,
              hex.hasPrefix("#"),
              hex.count == 7,
              let val = Int(hex.dropFirst(), radix: 16) else { return 0.5 }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8)  & 0xFF) / 255.0
        let b = Double( val        & 0xFF) / 255.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
