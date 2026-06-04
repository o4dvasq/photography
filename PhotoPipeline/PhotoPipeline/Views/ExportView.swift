//
//  ExportView.swift
//  PhotoPipeline
//
//  Export tab UI: Instagram resize + iCloud Photos import
//

import SwiftUI

struct ExportView: View {
    @EnvironmentObject var appState: AppState
    @State private var pendingFiles: [ExportFile] = []
    @State private var selectedFiles = Set<ExportFile>()
    @State private var isProcessing = false
    @State private var outputLog: [String] = []
    @State private var photosPermissionStatus: PhotosImporter.PhotosPermissionStatus = .notDetermined
    @State private var showPermissionBanner = false

    private let imageResizer = ImageResizer()
    private let photosImporter = PhotosImporter()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export to Instagram & Photos")
                .font(.title)
                .bold()

            watchFolderInfo
            permissionBanner
            fileList
            actionButtons
            logView

            Spacer()
        }
        .padding()
        .onAppear {
            checkPhotosPermission()
            scanPortfolioFolder()
        }
    }

    private var watchFolderInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Watch folder:")
                .font(.headline)

            Text(appState.preferences.portfolioPath)
                .foregroundColor(.secondary)
                .font(.caption)

            Button("Refresh") {
                scanPortfolioFolder()
            }
        }
    }

    private var permissionBanner: some View {
        Group {
            if showPermissionBanner {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("Photos access denied. Send to Photos is unavailable.")
                        .font(.callout)

                    Spacer()

                    Button("Open Settings") {
                        photosImporter.openSystemPreferences()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pending files: \(pendingFiles.count)")
                .font(.headline)

            if pendingFiles.isEmpty {
                Text("No new files in Portfolio")
                    .foregroundColor(.secondary)
            } else {
                List(pendingFiles, id: \.id, selection: $selectedFiles) { file in
                    HStack {
                        Text(file.filename)
                        Spacer()
                        if let dims = file.dimensions {
                            Text("\(dims.width) × \(dims.height)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if !file.needsResize(targetLongEdge: appState.preferences.instagramLongEdgeTarget) {
                            Text("≤ \(appState.preferences.instagramLongEdgeTarget)px")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Export to Instagram") {
                exportToInstagram()
            }
            .disabled(pendingFiles.isEmpty || isProcessing)

            Button("Send to Photos") {
                sendToPhotos()
            }
            .disabled(!canSendToPhotos)

            Button("Export + Send") {
                exportAndSend()
            }
            .disabled(!canExportAndSend)
            .buttonStyle(.borderedProminent)
        }
    }

    private var logView: some View {
        Group {
            if !outputLog.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output log:")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(outputLog, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.2))
                }
            }
        }
    }

    private var canSendToPhotos: Bool {
        photosPermissionStatus == .authorized && !isProcessing && hasFilesInStaged()
    }

    private var canExportAndSend: Bool {
        !pendingFiles.isEmpty && photosPermissionStatus == .authorized && !isProcessing
    }

    private func checkPhotosPermission() {
        photosPermissionStatus = photosImporter.checkPermission()

        if photosPermissionStatus == .denied {
            showPermissionBanner = true
        } else if photosPermissionStatus == .notDetermined {
            photosImporter.requestPermission { granted in
                DispatchQueue.main.async {
                    photosPermissionStatus = granted ? .authorized : .denied
                    showPermissionBanner = !granted
                }
            }
        }
    }

    private func scanPortfolioFolder() {
        let portfolioPath = appState.preferences.portfolioPath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: portfolioPath) else {
            pendingFiles = []
            return
        }

        pendingFiles = contents
            .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") }
            .compactMap { filename in
                let path = (portfolioPath as NSString).appendingPathComponent(filename)
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? Int64,
                      let modDate = attrs[.modificationDate] as? Date else {
                    return nil
                }
                return ExportFile(path: path, filename: filename, size: size, modifiedDate: modDate)
            }
            .sorted { $0.modifiedDate > $1.modifiedDate }
    }

    private func hasFilesInStaged() -> Bool {
        let stagedPath = appState.preferences.instagramStagedPath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: stagedPath) else {
            return false
        }
        return !contents.filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") }.isEmpty
    }

    private func exportToInstagram() {
        let filesToProcess = selectedFiles.isEmpty ? pendingFiles : Array(selectedFiles)

        isProcessing = true
        outputLog = []

        let outputDir = appState.preferences.instagramStagedPath
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        DispatchQueue.global(qos: .userInitiated).async {
            for file in filesToProcess {
                let result = imageResizer.resizeForInstagram(
                    sourcePath: file.path,
                    outputDirectory: outputDir,
                    longEdgeTarget: appState.preferences.instagramLongEdgeTarget,
                    jpegQuality: appState.preferences.jpegExportQuality,
                    stripGPS: appState.preferences.stripGPSMetadata
                )

                DispatchQueue.main.async {
                    if result.success {
                        if result.skipped {
                            outputLog.append("✓ \(file.filename): copied as-is (already ≤ 1080px)")
                        } else if let origDims = result.originalDimensions, let outDims = result.outputDimensions {
                            outputLog.append("✓ \(file.filename): \(origDims.width)×\(origDims.height) → \(outDims.width)×\(outDims.height)")
                        }
                    } else {
                        outputLog.append("✗ \(file.filename): \(result.error ?? "unknown error")")
                    }
                }
            }

            DispatchQueue.main.async {
                isProcessing = false
                outputLog.append("Export complete. \(filesToProcess.count) files processed.")
            }
        }
    }

    private func sendToPhotos() {
        guard photosPermissionStatus == .authorized else { return }

        let stagedPath = appState.preferences.instagramStagedPath
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: stagedPath) else {
            return
        }

        let filePaths = contents
            .filter { $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") }
            .map { (stagedPath as NSString).appendingPathComponent($0) }

        if filePaths.isEmpty {
            outputLog.append("No files in Instagram-Staged to import")
            return
        }

        isProcessing = true

        photosImporter.importFiles(
            at: filePaths,
            alreadyImported: appState.photosImportedFiles,
            progress: { message in
                outputLog.append(message)
            },
            completion: { result in
                isProcessing = false

                if result.success {
                    outputLog.append("✓ Photos import complete: \(result.importedCount) imported, \(result.skippedCount) skipped")
                } else {
                    outputLog.append("⚠️ Photos import completed with errors: \(result.importedCount) imported, \(result.failedCount) failed")
                    outputLog.append(contentsOf: result.errors)
                }

                for path in filePaths where !appState.hasPhotoBeenImported(path) {
                    appState.markPhotoAsImported(path)
                }
            }
        )
    }

    private func exportAndSend() {
        exportToInstagram()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if !isProcessing {
                sendToPhotos()
            }
        }
    }
}
