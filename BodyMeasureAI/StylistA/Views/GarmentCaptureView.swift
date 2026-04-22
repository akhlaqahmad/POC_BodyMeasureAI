//
//  GarmentCaptureView.swift
//  BodyMeasureAI
//
//  Garment photo input: Take Photo / Choose from Library, preview, Analyse button.
//

import SwiftUI
import UIKit
import PhotosUI

struct GarmentCaptureView: View {
    @ObservedObject var viewModel: GarmentCaptureViewModel
    @ObservedObject var coordinator: AppCoordinator
    @State private var showCamera = false
    @State private var showPhotoLibrary = false

    var body: some View {
        ZStack {
            Color("sBackground").ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(alignment: .leading, spacing: SSpacing.xs) {
                    Text("GARMENT SCAN")
                        .font(SFont.label(11))
                        .tracking(3)
                        .foregroundStyle(Color("sTertiary"))
                    Text("Add a piece")
                        .font(SFont.display(34, weight: .light))
                        .foregroundStyle(Color("sPrimary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SSpacing.lg)
                .padding(.top, SSpacing.xl)
                .padding(.bottom, SSpacing.lg)

                if let image = viewModel.selectedImage {

                    // Image preview
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.lg))
                        .padding(.horizontal, SSpacing.lg)
                        .softShadow()

                    Spacer().frame(height: SSpacing.lg)

                    if viewModel.isAnalyzing {
                        HStack(spacing: SSpacing.sm) {
                            ProgressView().tint(Color("sPrimary"))
                            Text(viewModel.measureGarmentBeta
                                 ? "Analysing + measuring…"
                                 : "Analysing…")
                                .font(SFont.label(14))
                                .foregroundStyle(Color("sSecondary"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(SSpacing.md)
                        .background(Color("sSurface"))
                        .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        .padding(.horizontal, SSpacing.lg)
                    } else {
                        Toggle(isOn: $viewModel.measureGarmentBeta) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Measure garment (beta)")
                                    .font(SFont.label(13))
                                    .foregroundStyle(Color("sPrimary"))
                                Text("Place a credit card flat next to the garment for scale.")
                                    .font(SFont.body(11))
                                    .foregroundStyle(Color("sTertiary"))
                            }
                        }
                        .tint(Color("sAccent"))
                        .padding(.horizontal, SSpacing.lg)
                        .padding(.bottom, SSpacing.xs)

                        if let note = viewModel.measurementNote {
                            Text(note)
                                .font(SFont.body(12))
                                .foregroundStyle(Color("sError"))
                                .padding(.horizontal, SSpacing.lg)
                                .padding(.bottom, SSpacing.xs)
                        }

                        Button(action: {
                            Task {
                                await viewModel.analyzeGarment(
                                    image: image,
                                    body: coordinator.bodyResult
                                )
                                if let result = viewModel.analysisResult {
                                    coordinator.garmentAnalysed(result: result)
                                }
                            }
                        }) {
                            HStack {
                                Text("Analyse Garment")
                                    .font(SFont.label(15))
                                    .tracking(0.5)
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(Color("sBackground"))
                            .padding(SSpacing.md)
                            .background(Color("sAccent"))
                            .clipShape(RoundedRectangle(cornerRadius: SRadius.md))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, SSpacing.lg)
                    }

                    Spacer().frame(height: SSpacing.sm)

                    HStack(spacing: SSpacing.sm) {
                        garmentSourceButton("camera.fill", "Take Photo") {
                            showCamera = true }
                        garmentSourceButton(
                            "photo.on.rectangle", "Library") {
                            showPhotoLibrary = true }
                    }
                    .padding(.horizontal, SSpacing.lg)

                } else {
                    // Empty state
                    Spacer()

                    VStack(spacing: SSpacing.lg) {
                        ZStack {
                            RoundedRectangle(cornerRadius: SRadius.lg)
                                .stroke(Color("sBorder"),
                                        style: StrokeStyle(
                                            lineWidth: 1, dash: [6, 4]))
                                .frame(height: 260)

                            VStack(spacing: SSpacing.md) {
                                Image(systemName: "tshirt")
                                    .font(.system(size: 40, weight: .light))
                                    .foregroundStyle(Color("sTertiary"))
                                Text("Add a garment photo")
                                    .font(SFont.body(16))
                                    .foregroundStyle(Color("sSecondary"))
                                Text("Take a photo or choose\nfrom your library")
                                    .font(SFont.body(13))
                                    .foregroundStyle(Color("sTertiary"))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, SSpacing.lg)

                        HStack(spacing: SSpacing.sm) {
                            garmentSourceButton("camera.fill", "Take Photo") {
                                showCamera = true }
                            garmentSourceButton(
                                "photo.on.rectangle", "Library") {
                                showPhotoLibrary = true }
                        }
                        .padding(.horizontal, SSpacing.lg)
                    }

                    Spacer()
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(SFont.body(13))
                        .foregroundStyle(Color("sError"))
                        .padding(.horizontal, SSpacing.lg)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                viewModel.setSelectedImage(image)
                showCamera = false
            } onCancel: {
                showCamera = false
            }
        }
        .fullScreenCover(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker { image in
                viewModel.setSelectedImage(image)
                showPhotoLibrary = false
            } onCancel: {
                showPhotoLibrary = false
            }
        }
        .keepScreenAwake()
    }

    private func garmentSourceButton(
        _ icon: String,
        _ label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(SFont.label(13))
            }
            .foregroundStyle(Color("sPrimary"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, SSpacing.sm + 2)
            .background(Color("sSurfaceElevated"))
            .clipShape(RoundedRectangle(cornerRadius: SRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera picker (UIImagePickerController)

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImage(img)
            } else {
                parent.onCancel()
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Photo library (PHPickerViewController)

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPicker
        init(_ parent: PhotoLibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.onCancel()
                return
            }
            result.itemProvider.loadObject(ofClass: UIImage.self) { [parent] obj, _ in
                DispatchQueue.main.async {
                    if let img = obj as? UIImage {
                        parent.onImage(img)
                    } else {
                        parent.onCancel()
                    }
                }
            }
        }
    }
}
