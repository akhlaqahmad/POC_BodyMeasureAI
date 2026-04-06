# Plan: Image Storage, Scan History & History Screens

## Context

Currently the app captures body measurements and garment analysis but **never persists images** and has **no history screen**. Garment photos are held in memory and discarded. Body scans produce only numerical data with no snapshot. The `ScanDatabaseService.fetchUserScans()` method exists but is never called from any UI. This plan adds local+cloud image storage, individual scan persistence, and a tab-based history screen.

---

## Phase A: Foundation (compiles, no UI changes)

### Step 1 — Extend AppwriteService with Storage

**File:** `BodyMeasureAI/StylistA/Services/AppwriteService.swift`

- Add to `AppwriteConfig`:
  - `static let bodyScansCollectionId = "body_scans"`
  - `static let garmentScansCollectionId = "garment_scans"`
  - `static let imagesBucketId = "scan_images"`
- Add to `AppwriteService`:
  - `let storage: Storage` (initialized from existing `client`)

**Appwrite Console prerequisite** (manual):
- Create Storage bucket `scan_images` (10MB max, JPEG)
- Create collection `body_scans` in `stylista_db` with fields: `userId`, `scanId`, `scanTimestamp`, `heightCm`, `gender`, `positiveMessage`, `verticalType`, `isPetite`, `captureConfidence`, `measurementsJSON`, `imageLocalFilename`, `imageRemoteFileId`
- Create collection `garment_scans` in `stylista_db` with fields: `userId`, `scanId`, `scanTimestamp`, `garmentDataJSON`, `imageLocalFilename`, `imageRemoteFileId`
- Index both on `userId` + `scanTimestamp` descending

### Step 2 — Add image fields to models

**File:** `BodyMeasureAI/StylistA/Models/BodyScanResult.swift`
- Add `var imageLocalFilename: String? = nil` to `BodyScanResult`
- Add `var imageRemoteFileId: String? = nil` to `BodyScanResult`
- Include in `exportJSON` when non-nil

**File:** `BodyMeasureAI/StylistA/Models/GarmentTagModel.swift`
- Add `var imageLocalFilename: String? = nil` to `GarmentTagModel`
- Add `var imageRemoteFileId: String? = nil` to `GarmentTagModel`
- Include in `exportJSON` when non-nil
- Note: These have `nil` defaults so all existing call sites compile unchanged

### Step 3 — Create ImageStorageService

**New file:** `BodyMeasureAI/StylistA/Services/ImageStorageService.swift`

Singleton following the `.shared` pattern. Responsibilities:
- `saveImageLocally(image: UIImage, prefix: String) -> String` — saves JPEG (0.8 quality) to `Documents/ScanImages/{prefix}_{UUID}.jpg`, returns filename only
- `loadLocalImage(filename: String) -> UIImage?` — loads from `Documents/ScanImages/`
- `loadThumbnail(filename: String, maxPixels: CGFloat = 200) -> UIImage?` — uses `CGImageSourceCreateThumbnailAtIndex` for memory-efficient list rendering
- `uploadToCloud(filename: String) async -> String?` — uploads to Appwrite Storage bucket `scan_images`, returns file ID
- `downloadFromCloud(fileId: String, filename: String) async -> UIImage?` — downloads from Appwrite, caches locally
- `ensureDirectory()` — creates `Documents/ScanImages/` if needed (called in init)

---

## Phase B: Capture & Persist (scans save images + individual records)

### Step 4 — Capture body scan snapshot

**File:** `BodyMeasureAI/StylistA/ViewModels/BodyCaptureViewModel.swift`

- Add `private var latestPixelBuffer: CVPixelBuffer?` property
- In `captureOutput(_:didOutput:from:)` after extracting pixelBuffer, store it
- In `finalizeCapture()` after creating result:
  - Convert `latestPixelBuffer` to UIImage via CIImage/CIContext/CGImage (with `.right` orientation for portrait)
  - Call `ImageStorageService.shared.saveImageLocally(image:prefix:"body")` → set `result.imageLocalFilename`
  - Fire background upload

### Step 5 — Persist garment image

**File:** `BodyMeasureAI/StylistA/ViewModels/GarmentCaptureViewModel.swift`

- In `analyzeGarment(image:)`, after `analysisResult = result`:
  - Call `ImageStorageService.shared.saveImageLocally(image:prefix:"garment")` → set `result.imageLocalFilename`
  - Fire background upload task

### Step 6 — Extend ScanDatabaseService with individual scan persistence

**File:** `BodyMeasureAI/StylistA/Services/ScanDatabaseService.swift`

Add two history item structs (`BodyScanHistoryItem`, `GarmentScanHistoryItem`) conforming to `Identifiable` and `Hashable`.

Add methods:
- `saveBodyScan(_ result: BodyScanResult) async throws`
- `saveGarmentScan(_ result: GarmentTagModel) async throws`
- `fetchBodyScans() async throws -> [BodyScanHistoryItem]`
- `fetchGarmentScans() async throws -> [GarmentScanHistoryItem]`
- `updateImageRemoteId(collectionId:documentId:fileId:) async`

---

## Phase C: History UI

### Step 7 — Add FlowStep cases and coordinator methods

**File:** `BodyMeasureAI/StylistA/App/AppCoordinator.swift`

- Add `.history`, `.bodyScanDetail(BodyScanHistoryItem)`, `.garmentScanDetail(GarmentScanHistoryItem)` to FlowStep
- Add `openHistory()`, `openBodyScanDetail(_:)`, `openGarmentScanDetail(_:)` methods
- In `bodyCaptured(result:)` — fire-and-forget save to `body_scans`
- In `garmentAnalysed(result:)` — fire-and-forget save to `garment_scans`

### Step 8 — Create HistoryViewModel

**New file:** `BodyMeasureAI/StylistA/ViewModels/HistoryViewModel.swift`

### Step 9 — Create HistoryView (tab-based)

**New file:** `BodyMeasureAI/StylistA/Views/HistoryView.swift`

### Step 10 — Create detail views

**New files:**
- `BodyMeasureAI/StylistA/Views/BodyScanDetailView.swift`
- `BodyMeasureAI/StylistA/Views/GarmentScanDetailView.swift`

### Step 11 — Wire navigation

**Files:** `ContentView.swift`, `OnboardingView.swift`

---

## Files Summary

| Action | File |
|--------|------|
| Modify | `Services/AppwriteService.swift` |
| Modify | `Models/BodyScanResult.swift` |
| Modify | `Models/GarmentTagModel.swift` |
| Create | `Services/ImageStorageService.swift` |
| Modify | `ViewModels/BodyCaptureViewModel.swift` |
| Modify | `ViewModels/GarmentCaptureViewModel.swift` |
| Modify | `Services/ScanDatabaseService.swift` |
| Modify | `App/AppCoordinator.swift` |
| Create | `ViewModels/HistoryViewModel.swift` |
| Create | `Views/HistoryView.swift` |
| Create | `Views/BodyScanDetailView.swift` |
| Create | `Views/GarmentScanDetailView.swift` |
| Modify | `ContentView.swift` |
| Modify | `Views/OnboardingView.swift` |
