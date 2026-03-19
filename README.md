# POC Body Measure AI

A proof-of-concept iOS application built with SwiftUI for capturing body measurements, extracting body proportions, classifying garments, and providing styling analysis using AI and Computer Vision technologies.

## 📁 Project Structure Overview

The project follows an MVVM (Model-View-ViewModel) architecture organized by functional domains within the `BodyMeasureAI/StylistA` directory:

### **App Configuration & Coordination**
- `App/AppCoordinator.swift`: Manages application-level routing and state.
- `BodyMeasureAIApp.swift`: SwiftUI application entry point.
- `ContentView.swift`: Main content view wrapper.

### **Views (`Views/`)**
Contains the SwiftUI user interface components for different phases of the app:
- **Onboarding:** `OnboardingView.swift`
- **Body Capture:** `BodyCaptureView.swift`, `MultiAngleBodyScanView.swift`
- **Garment Capture:** `GarmentCaptureView.swift`
- **Results:** `FinalScanResultView.swift`, `GarmentResultView.swift`, `ResultsView.swift`
- **Validation:** `ValidationModeView.swift`

### **ViewModels (`ViewModels/`)**
Manages state and business logic connecting views to services:
- `BodyCaptureViewModel.swift`: Handles camera and body scanning state.
- `BodyClassificationEngine.swift`: Processes scanning data to compute classification.
- `GarmentCaptureViewModel.swift`: Handles garment scanning state.

### **Services (`Services/`)**
Core processing, AI, and data handling layers:
- `GarmentClassifierService.swift`: Handles garment type and feature classification.
- `GarmentColorExtractor.swift`: Extracts and categorizes primary/secondary colors from garments.
- `JSONExportService.swift`: Exports scanned data/measurements into JSON format.
- `KeypointNormalizer.swift`: Normalizes vision framework keypoints for body modeling.

### **Models (`Models/`)**
Data structures representing the domain entities:
- `BodyProportionModel.swift`: Data model for computed body proportions.
- `BodyScanResult.swift`: Comprehensive results of a single body scan.
- `GarmentTagModel.swift`: Tags, characteristics, and classifications for a scanned garment.
- `ScanSessionModel.swift`: Represents a complete user session including both body and garment data.

### **Design System (`DesignSystem/`)**
- `DesignSystem.swift`: Reusable UI tokens, styling components, and thematic elements.
- `Assets.xcassets`: Application resources including a rich set of semantic colors (`sAccent`, `sPrimary`, `sSuccess`, `sSurface`, etc.).

## 🚀 Getting Started

1. Open `BodyMeasureAI.xcodeproj` in Xcode.
2. Select your target device or simulator.
3. Build and Run (`Cmd + R`).

*Note: The project heavily relies on device camera and Vision capabilities. Testing on a physical iOS device is highly recommended for accurate body and garment scanning.*

## ✅ Testing
- Unit tests are located in `BodyMeasureAITests`
- UI tests are located in `BodyMeasureAIUITests`
