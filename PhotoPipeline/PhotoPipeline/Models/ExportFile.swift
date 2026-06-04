//
//  ExportFile.swift
//  PhotoPipeline
//
//  Model for a pending export file
//

import Foundation
import ImageIO

struct ExportFile: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let filename: String
    let size: Int64
    let modifiedDate: Date

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var dimensions: (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int else {
            return nil
        }
        return (width, height)
    }

    func needsResize(targetLongEdge: Int) -> Bool {
        guard let dims = dimensions else { return false }
        let longEdge = max(dims.width, dims.height)
        return longEdge > targetLongEdge
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: ExportFile, rhs: ExportFile) -> Bool {
        lhs.path == rhs.path
    }
}
