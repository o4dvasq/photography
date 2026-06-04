//
//  FileImporter.swift
//  PhotoPipeline
//
//  Copy + organize files into dated folders with collision handling
//

import Foundation

class FileImporter {
    private let fileManager = FileManager.default

    struct ImportResult {
        let sessionFolderName: String
        let destinationPath: String
        let rawCopied: Int
        let jpegCopied: Int
        let errors: [String]
    }

    func performImport(
        rawFiles: [URL],
        jpegFiles: [URL],
        sessionDate: Date,
        baseImportsPath: String,
        progress: @escaping (String) -> Void
    ) -> ImportResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: sessionDate)

        let sessionFolderName = resolveCollision(baseName: dateString, in: baseImportsPath)
        let sessionPath = (baseImportsPath as NSString).appendingPathComponent(sessionFolderName)
        let rawPath = (sessionPath as NSString).appendingPathComponent("RAW")
        let jpegPath = (sessionPath as NSString).appendingPathComponent("JPEG")

        var errors: [String] = []

        do {
            try fileManager.createDirectory(atPath: rawPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: jpegPath, withIntermediateDirectories: true)
        } catch {
            errors.append("Failed to create directories: \(error.localizedDescription)")
            return ImportResult(
                sessionFolderName: sessionFolderName,
                destinationPath: sessionPath,
                rawCopied: 0,
                jpegCopied: 0,
                errors: errors
            )
        }

        var rawCopied = 0
        var jpegCopied = 0

        for rawFile in rawFiles {
            progress("Copying \(rawFile.lastPathComponent)...")
            let dest = URL(fileURLWithPath: rawPath).appendingPathComponent(rawFile.lastPathComponent)
            do {
                try fileManager.copyItem(at: rawFile, to: dest)
                rawCopied += 1
            } catch {
                errors.append("Failed to copy \(rawFile.lastPathComponent): \(error.localizedDescription)")
            }
        }

        for jpegFile in jpegFiles {
            progress("Copying \(jpegFile.lastPathComponent)...")
            let dest = URL(fileURLWithPath: jpegPath).appendingPathComponent(jpegFile.lastPathComponent)
            do {
                try fileManager.copyItem(at: jpegFile, to: dest)
                jpegCopied += 1
            } catch {
                errors.append("Failed to copy \(jpegFile.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return ImportResult(
            sessionFolderName: sessionFolderName,
            destinationPath: sessionPath,
            rawCopied: rawCopied,
            jpegCopied: jpegCopied,
            errors: errors
        )
    }

    private func resolveCollision(baseName: String, in directory: String) -> String {
        var candidate = baseName
        var suffix = "b"

        while fileManager.fileExists(atPath: (directory as NSString).appendingPathComponent(candidate)) {
            candidate = "\(baseName)-\(suffix)"

            if suffix == "z" {
                suffix = "27"
            } else if let lastChar = suffix.last, lastChar.isLetter, let asciiValue = lastChar.asciiValue {
                suffix = String(Character(UnicodeScalar(asciiValue + 1))).lowercased()
            } else if let num = Int(suffix) {
                suffix = "\(num + 1)"
            } else {
                suffix = "27"
            }
        }

        return candidate
    }
}
