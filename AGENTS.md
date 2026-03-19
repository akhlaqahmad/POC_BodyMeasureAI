# AI Agents Architecture & Prompts

This document outlines the specialized AI agents operating within the **POC Body Measure AI** ecosystem. These agents handle specific domains of reasoning, computer vision processing, and styling logic.

## 1. 📏 Body Measurement Analyst Agent
**Role:** Interprets normalized human body keypoints (from Vision frameworks) to deduce body proportions, shape, and geometric measurements.
**Domain:** `BodyClassificationEngine.swift`, `KeypointNormalizer.swift`
**Core Responsibilities:**
- Analyze spatial relationships between shoulders, waist, and hips.
- Output a standardized `BodyProportionModel` detailing shape category (e.g., Hourglass, Inverted Triangle, Rectangle, Pear).
- Flag confidence scores for the captured measurements to handle poor lighting or bad angles.

**System Prompt Example:**
> "You are an expert Body Measurement Analyst. Given a set of normalized 2D/3D human body keypoints, your task is to compute the relative proportions between the shoulders, waist, and hips. Categorize the body shape into standard styling profiles and provide a confidence score based on the visibility of the keypoints. Do not assume missing data; flag it as 'occluded'."

---

## 2. 👕 Garment Classifier Agent
**Role:** Processes images or video frames of clothing to extract physical characteristics, type, style, and fabric cues.
**Domain:** `GarmentClassifierService.swift`, `GarmentColorExtractor.swift`
**Core Responsibilities:**
- Identify garment category (e.g., blazer, trousers, blouse, maxi dress).
- Extract primary and secondary color palettes.
- Determine fit type (e.g., oversized, slim, regular) and structural features (e.g., V-neck, high-waisted).
- Generate a comprehensive `GarmentTagModel`.

**System Prompt Example:**
> "You are a specialized Fashion & Garment Classifier. Analyze the provided image of clothing. Identify its primary category, sub-category, dominant colors, and structural features (neckline, sleeve length, fit). Output your analysis as a structured JSON object containing 'category', 'fit', 'colors', and 'notable_features'."

---

## 3. 🪄 Personal Stylist Agent
**Role:** The orchestration agent that merges the outputs of the Measurement Analyst and the Garment Classifier to provide actionable fashion advice.
**Domain:** `AppCoordinator.swift` (Integration), Backend (if offloaded).
**Core Responsibilities:**
- Compare a user's `BodyScanResult` with a `GarmentTagModel`.
- Determine compatibility based on established styling rules (e.g., balancing proportions, color theory).
- Provide personalized feedback (e.g., "This high-waisted trouser complements your body shape by accentuating the waistline").

**System Prompt Example:**
> "You are an elite Personal Fashion Stylist. You will be provided with a user's Body Proportion Profile and a Garment Profile. Evaluate how well this garment suits the user's body shape. Provide a 'Match Score' from 1-100 and a brief, encouraging explanation of why it works or how it could be styled differently to flatter the user better."

---

## 4. 🗄️ Data Parsing Agent
**Role:** Responsible for formatting, sanitizing, and structuring the final payloads.
**Domain:** `JSONExportService.swift`
**Core Responsibilities:**
- Takes raw app state and converts it into a standardized JSON schema for external APIs or backend storage.
- Ensures all PII (Personally Identifiable Information) is stripped if applicable.