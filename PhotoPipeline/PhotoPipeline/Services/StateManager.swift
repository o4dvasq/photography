//
//  StateManager.swift
//  PhotoPipeline
//
//  Read/write state.json and import_history.json
//

import Foundation

class StateManager {
    private let fileManager = FileManager.default
    private let appSupportDir: URL

    private var stateFileURL: URL {
        appSupportDir.appendingPathComponent("state.json")
    }

    private var importHistoryURL: URL {
        appSupportDir.appendingPathComponent("import_history.json")
    }

    init() {
        let libraryDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportDir = libraryDir.appendingPathComponent("PhotoPipeline")

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Preferences

    func loadPreferences() -> AppState.Preferences {
        guard let data = try? Data(contentsOf: stateFileURL),
              let decoded = try? JSONDecoder().decode(PreferencesWrapper.self, from: data) else {
            return AppState.Preferences()
        }
        return decoded.preferences
    }

    func savePreferences(_ preferences: AppState.Preferences) {
        let wrapper = PreferencesWrapper(preferences: preferences)
        guard let encoded = try? JSONEncoder().encode(wrapper) else { return }
        try? encoded.write(to: stateFileURL)
    }

    private struct PreferencesWrapper: Codable {
        let preferences: AppState.Preferences
    }

    // MARK: - Import History

    func loadImportHistory() -> [ImportSession] {
        guard let data = try? Data(contentsOf: importHistoryURL),
              let decoded = try? JSONDecoder().decode([ImportSession].self, from: data) else {
            return []
        }
        return decoded
    }

    func saveImportHistory(_ history: [ImportSession]) {
        guard let encoded = try? JSONEncoder().encode(history) else { return }
        try? encoded.write(to: importHistoryURL)
    }

    // MARK: - Photos Import Log

    func loadPhotosImportLog() -> Set<String> {
        let logURL = appSupportDir.appendingPathComponent("photos_import_log.json")
        guard let data = try? Data(contentsOf: logURL),
              let decoded = try? JSONDecoder().decode(PhotosImportLog.self, from: data) else {
            return Set<String>()
        }
        return Set(decoded.importedFiles)
    }

    func savePhotosImportLog(_ imported: Set<String>) {
        let logURL = appSupportDir.appendingPathComponent("photos_import_log.json")
        let log = PhotosImportLog(importedFiles: Array(imported))
        guard let encoded = try? JSONEncoder().encode(log) else { return }
        try? encoded.write(to: logURL)
    }

    private struct PhotosImportLog: Codable {
        let importedFiles: [String]
    }
}
