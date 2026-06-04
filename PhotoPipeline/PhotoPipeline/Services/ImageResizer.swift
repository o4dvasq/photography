//
//  ImageResizer.swift
//  PhotoPipeline
//
//  Core Image / vImage resize + metadata strip for Instagram optimization
//

import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

class ImageResizer {
    struct ResizeResult {
        let success: Bool
        let outputPath: String?
        let originalDimensions: (width: Int, height: Int)?
        let outputDimensions: (width: Int, height: Int)?
        let skipped: Bool
        let error: String?
    }

    func resizeForInstagram(
        sourcePath: String,
        outputDirectory: String,
        longEdgeTarget: Int,
        jpegQuality: Int,
        stripGPS: Bool
    ) -> ResizeResult {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return ResizeResult(success: false, outputPath: nil, originalDimensions: nil, outputDimensions: nil, skipped: false, error: "Failed to load image")
        }

        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        let originalDimensions = (originalWidth, originalHeight)

        let orientation = readEXIFOrientation(from: imageSource)
        let rotatedImage = applyOrientation(cgImage: cgImage, orientation: orientation)

        let rotatedWidth = rotatedImage.width
        let rotatedHeight = rotatedImage.height
        let longEdge = max(rotatedWidth, rotatedHeight)

        if longEdge <= longEdgeTarget {
            let filename = (sourcePath as NSString).lastPathComponent
            let outputFilename = ((filename as NSString).deletingPathExtension as NSString).appendingPathExtension("jpg") ?? filename
            let outputPath = (outputDirectory as NSString).appendingPathComponent(outputFilename)

            if copyWithMetadataStripping(sourcePath: sourcePath, outputPath: outputPath, stripGPS: stripGPS) {
                return ResizeResult(
                    success: true,
                    outputPath: outputPath,
                    originalDimensions: originalDimensions,
                    outputDimensions: (rotatedWidth, rotatedHeight),
                    skipped: true,
                    error: nil
                )
            } else {
                return ResizeResult(success: false, outputPath: nil, originalDimensions: originalDimensions, outputDimensions: nil, skipped: false, error: "Failed to copy file")
            }
        }

        let scale = Double(longEdgeTarget) / Double(longEdge)
        let newWidth = Int(Double(rotatedWidth) * scale)
        let newHeight = Int(Double(rotatedHeight) * scale)

        guard let resizedCGImage = resizeImage(cgImage: rotatedImage, targetWidth: newWidth, targetHeight: newHeight) else {
            return ResizeResult(success: false, outputPath: nil, originalDimensions: originalDimensions, outputDimensions: nil, skipped: false, error: "Failed to resize")
        }

        let sourceFilename = (sourcePath as NSString).lastPathComponent
        let baseName = (sourceFilename as NSString).deletingPathExtension
        let outputFilename = "\(baseName)_ig.jpg"
        let outputPath = (outputDirectory as NSString).appendingPathComponent(outputFilename)

        guard saveJPEG(cgImage: resizedCGImage, to: outputPath, quality: jpegQuality, stripGPS: stripGPS, originalMetadata: imageSource) else {
            return ResizeResult(success: false, outputPath: nil, originalDimensions: originalDimensions, outputDimensions: nil, skipped: false, error: "Failed to save")
        }

        return ResizeResult(
            success: true,
            outputPath: outputPath,
            originalDimensions: originalDimensions,
            outputDimensions: (newWidth, newHeight),
            skipped: false,
            error: nil
        )
    }

    private func readEXIFOrientation(from imageSource: CGImageSource) -> CGImagePropertyOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let orientationValue = properties[kCGImagePropertyOrientation as String] as? UInt32 else {
            return .up
        }

        return CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
    }

    private func applyOrientation(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CGImage {
        if orientation == .up {
            return cgImage
        }

        let width = cgImage.width
        let height = cgImage.height
        let bitsPerComponent = cgImage.bitsPerComponent
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo

        var transform = CGAffineTransform.identity

        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: CGFloat(width), y: CGFloat(height))
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: CGFloat(height), y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: CGFloat(width))
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }

        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: CGFloat(width), y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: CGFloat(height), y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        guard let context = CGContext(
            data: nil,
            width: orientation.isPortrait ? height : width,
            height: orientation.isPortrait ? width : height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return cgImage
        }

        context.concatenate(transform)

        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return context.makeImage() ?? cgImage
    }

    private func resizeImage(cgImage: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage? {
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        return context.makeImage()
    }

    private func saveJPEG(cgImage: CGImage, to path: String, quality: Int, stripGPS: Bool, originalMetadata: CGImageSource) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return false
        }

        var properties: [String: Any] = [
            kCGImageDestinationLossyCompressionQuality as String: Double(quality) / 100.0
        ]

        if let originalProperties = CGImageSourceCopyPropertiesAtIndex(originalMetadata, 0, nil) as? [String: Any] {
            var metadata = originalProperties

            if stripGPS {
                metadata.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
            }

            properties = properties.merging(metadata) { current, _ in current }
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        return CGImageDestinationFinalize(destination)
    }

    private func copyWithMetadataStripping(sourcePath: String, outputPath: String, stripGPS: Bool) -> Bool {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return false
        }

        return saveJPEG(cgImage: cgImage, to: outputPath, quality: 90, stripGPS: stripGPS, originalMetadata: imageSource)
    }
}

extension CGImagePropertyOrientation {
    var isPortrait: Bool {
        switch self {
        case .left, .leftMirrored, .right, .rightMirrored:
            return true
        default:
            return false
        }
    }
}
