//
//  ImageStorageService.swift
//  BodyMeasureAI
//
//  Local + cloud image storage for scan snapshots and garment photos.
//

import Appwrite
import Foundation
import ImageIO
import NIOFoundationCompat
import UIKit

final class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let imagesDirectoryName = "ScanImages"
    private let jpegQuality: CGFloat = 0.8

    private var imagesDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(imagesDirectoryName)
    }

    private init() {
        ensureDirectory()
    }

    // MARK: - Local Storage

    /// Save UIImage as JPEG locally. Returns the filename (not the full path).
    func saveImageLocally(image: UIImage, prefix: String) -> String? {
        guard let data = image.jpegData(compressionQuality: jpegQuality) else {
            Log.error("Failed to create JPEG data")
            return nil
        }
        let filename = "\(prefix)_\(UUID().uuidString).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            Log.info("Image saved locally", context: ["filename": filename, "sizeKB": data.count / 1024])
            return filename
        } catch {
            Log.error("Image write failed", context: ["error": error.localizedDescription])
            return nil
        }
    }

    /// Load full-resolution image from local storage.
    func loadLocalImage(filename: String) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Load a downsampled thumbnail for efficient list rendering.
    func loadThumbnail(filename: String, maxPixels: CGFloat = 200) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Full path for a filename (used when uploading).
    func localPath(for filename: String) -> URL {
        imagesDirectory.appendingPathComponent(filename)
    }

    // MARK: - Cloud Storage (Appwrite)

    /// Upload a locally stored image to Appwrite Storage. Returns the remote file ID.
    func uploadToCloud(filename: String) async -> String? {
        let url = localPath(for: filename)
        guard fileManager.fileExists(atPath: url.path) else {
            Log.warn("File not found for upload", context: ["filename": filename])
            return nil
        }
        do {
            let file = try await AppwriteService.shared.storage.createFile(
                bucketId: AppwriteConfig.imagesBucketId,
                fileId: ID.unique(),
                file: InputFile.fromPath(url.path)
            )
            Log.info("Image uploaded to cloud", context: ["filename": filename, "fileId": file.id])
            return file.id
        } catch {
            Log.error("Image upload failed", context: ["error": error.localizedDescription])
            return nil
        }
    }

    /// Download an image from Appwrite Storage and cache it locally.
    func downloadFromCloud(fileId: String, filename: String) async -> UIImage? {
        // Check local cache first
        if let cached = loadLocalImage(filename: filename) {
            return cached
        }
        do {
            let buffer = try await AppwriteService.shared.storage.getFileDownload(
                bucketId: AppwriteConfig.imagesBucketId,
                fileId: fileId
            )
            let data = Data(buffer: buffer)
            let url = imagesDirectory.appendingPathComponent(filename)
            try data.write(to: url)
            return UIImage(data: data)
        } catch {
            Log.error("Image download failed", context: ["error": error.localizedDescription])
            return nil
        }
    }

    // MARK: - Helpers

    private func ensureDirectory() {
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }
}
