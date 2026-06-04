//
//  AppState.swift
//  PhotoPipeline
//
//  Observable app state: preferences, import history, Photos log
//

import Foundation
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var preferences: Preferences
    @Published var importHistory: [ImportSession] = []
    @Published var photosImportedFiles: Set<String> = []

    private let stateManager = StateManager()

    struct Preferences: Codable, Equatable {
        var basePhotographyFolder: String = NSHomeDirectory() + "/Photography"
        var autoOpenOnSDCard: Bool = true
        var showMenubarIcon: Bool = true
        var stripGPSMetadata: Bool = true
        var instagramLongEdgeTarget: Int = 1080
        var jpegExportQuality: Int = 90

        var importsPath: String {
            basePhotographyFolder + "/Imports"
        }

        var exportsPath: String {
            basePhotographyFolder + "/Exports"
        }

        var portfolioPath: String {
            exportsPath + "/Portfolio"
        }

        var instagramStagedPath: String {
            exportsPath + "/Instagram-Staged"
        }
    }

    private init() {
        self.preferences = stateManager.loadPreferences()
        self.importHistory = stateManager.loadImportHistory()
        self.photosImportedFiles = stateManager.loadPhotosImportLog()
    }

    func savePreferences() {
        stateManager.savePreferences(preferences)
    }

    func addImportSession(_ session: ImportSession) {
        importHistory.insert(session, at: 0)
        stateManager.saveImportHistory(importHistory)
    }

    func markPhotoAsImported(_ filePath: String) {
        photosImportedFiles.insert(filePath)
        stateManager.savePhotosImportLog(photosImportedFiles)
    }

    func hasPhotoBeenImported(_ filePath: String) -> Bool {
        return photosImportedFiles.contains(filePath)
    }
}
