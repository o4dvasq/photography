//
//  PhotosImporter.swift
//  PhotoPipeline
//
//  PhotoKit PHPhotoLibrary import for iCloud Photos integration
//

import Foundation
import Photos
import AppKit

class PhotosImporter {
    enum PhotosPermissionStatus {
        case authorized
        case denied
        case notDetermined
    }

    struct ImportResult {
        let success: Bool
        let importedCount: Int
        let skippedCount: Int
        let failedCount: Int
        let errors: [String]
    }

    func checkPermission() -> PhotosPermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }

    func importFiles(
        at paths: [String],
        alreadyImported: Set<String>,
        progress: @escaping (String) -> Void,
        completion: @escaping (ImportResult) -> Void
    ) {
        var importedCount = 0
        var skippedCount = 0
        var failedCount = 0
        var errors: [String] = []

        let filesToImport = paths.filter { !alreadyImported.contains($0) }

        if filesToImport.isEmpty {
            completion(ImportResult(
                success: true,
                importedCount: 0,
                skippedCount: paths.count,
                failedCount: 0,
                errors: []
            ))
            return
        }

        let group = DispatchGroup()
        let syncQueue = DispatchQueue(label: "com.photopipeline.photos.sync")

        for filePath in filesToImport {
            group.enter()
            let filename = (filePath as NSString).lastPathComponent
            progress("Importing \(filename)...")

            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: URL(fileURLWithPath: filePath), options: nil)
            }) { success, error in
                syncQueue.async {
                    if success {
                        importedCount += 1
                    } else {
                        failedCount += 1
                        if let error = error {
                            errors.append("Failed to import \(filename): \(error.localizedDescription)")
                        }
                    }
                    group.leave()
                }
            }
        }

        skippedCount = paths.count - filesToImport.count

        group.notify(queue: .main) {
            completion(ImportResult(
                success: failedCount == 0,
                importedCount: importedCount,
                skippedCount: skippedCount,
                failedCount: failedCount,
                errors: errors
            ))
        }
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }
}
