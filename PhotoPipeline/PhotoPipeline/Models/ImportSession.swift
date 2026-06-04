//
//  ImportSession.swift
//  PhotoPipeline
//
//  Model for an import session (date, counts, paths)
//

import Foundation

struct ImportSession: Codable, Identifiable {
    let id: UUID
    let date: Date
    let sessionFolderName: String
    let sourceVolumePath: String
    let rawCount: Int
    let jpegCount: Int
    let destinationPath: String

    init(date: Date, sessionFolderName: String, sourceVolumePath: String, rawCount: Int, jpegCount: Int, destinationPath: String) {
        self.id = UUID()
        self.date = date
        self.sessionFolderName = sessionFolderName
        self.sourceVolumePath = sourceVolumePath
        self.rawCount = rawCount
        self.jpegCount = jpegCount
        self.destinationPath = destinationPath
    }

    var summary: String {
        "\(sessionFolderName): \(rawCount) RAW, \(jpegCount) JPEG from \(sourceVolumePath)"
    }
}
