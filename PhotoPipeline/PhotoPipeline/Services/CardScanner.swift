//
//  CardScanner.swift
//  PhotoPipeline
//
//  Scans SD card for RAF/JPEG files
//

import Foundation

class CardScanner {
    struct ScanResult {
        let rawFiles: [URL]
        let jpegFiles: [URL]

        var totalCount: Int {
            rawFiles.count + jpegFiles.count
        }

        var summary: String {
            "\(rawFiles.count) RAF, \(jpegFiles.count) JPEG"
        }
    }

    func scanVolume(at path: String) -> ScanResult {
        let volumeURL = URL(fileURLWithPath: path)
        let dcimURL = volumeURL.appendingPathComponent("DCIM")

        var rawFiles: [URL] = []
        var jpegFiles: [URL] = []

        if let enumerator = FileManager.default.enumerator(
            at: dcimURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else {
                    continue
                }

                let ext = fileURL.pathExtension.lowercased()

                if ext == "raf" {
                    rawFiles.append(fileURL)
                } else if ext == "jpg" || ext == "jpeg" {
                    jpegFiles.append(fileURL)
                }
            }
        }

        return ScanResult(rawFiles: rawFiles, jpegFiles: jpegFiles)
    }
}
