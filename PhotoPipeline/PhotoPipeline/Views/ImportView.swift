//
//  ImportView.swift
//  PhotoPipeline
//
//  Import tab UI: SD card import with RAW/JPEG split
//

import SwiftUI

struct ImportView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedVolume: String = ""
    @State private var sessionDate = Date()
    @State private var scanResult: CardScanner.ScanResult?
    @State private var isImporting = false
    @State private var importProgress = ""
    @State private var importLog: [String] = []
    @State private var importComplete = false
    @State private var lastImportPath: String?

    private let sdCardDetector = SDCardDetector()
    private let cardScanner = CardScanner()
    private let fileImporter = FileImporter()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import from SD Card")
                .font(.title)
                .bold()

            sourceSelection
            sessionDatePicker
            scanResults
            importButton
            progressView
            logView

            Spacer()
        }
        .padding()
        .onAppear {
            detectSDCards()
        }
    }

    private var sourceSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source:")
                .font(.headline)

            HStack {
                Picker("", selection: $selectedVolume) {
                    Text("Select volume...").tag("")
                    ForEach(sdCardDetector.getMountedSDCards(), id: \.self) { volume in
                        Text(volume).tag(volume)
                    }
                }
                .frame(width: 300)
                .onChange(of: selectedVolume) { newValue in
                    if !newValue.isEmpty {
                        scanVolume()
                    }
                }

                Button("Choose Folder...") {
                    chooseFolder()
                }

                Button("Refresh") {
                    detectSDCards()
                }
            }
        }
    }

    private var sessionDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session date:")
                .font(.headline)

            DatePicker("", selection: $sessionDate, displayedComponents: .date)
                .datePickerStyle(.field)
                .labelsHidden()
        }
    }

    private var scanResults: some View {
        Group {
            if let result = scanResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Files found:")
                        .font(.headline)

                    Text(result.summary)
                        .foregroundColor(.secondary)

                    if result.totalCount > 0 {
                        Text("Destination: \(destinationPreview)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var importButton: some View {
        Button("Import") {
            performImport()
        }
        .disabled(!canImport)
        .buttonStyle(.borderedProminent)
    }

    private var progressView: some View {
        Group {
            if isImporting {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text(importProgress)
                        .font(.caption)
                }
            }
        }
    }

    private var logView: some View {
        Group {
            if !importLog.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import log:")
                        .font(.headline)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(importLog, id: \.self) { entry in
                                Text(entry)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.2))

                    if importComplete, let path = lastImportPath {
                        Button("Reveal RAW folder in Finder") {
                            let rawPath = (path as NSString).appendingPathComponent("RAW")
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: rawPath)
                        }
                    }
                }
            }
        }
    }

    private var canImport: Bool {
        !selectedVolume.isEmpty && scanResult != nil && scanResult!.totalCount > 0 && !isImporting
    }

    private var destinationPreview: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: sessionDate)
        return "\(appState.preferences.importsPath)/\(dateString)/{RAW,JPEG}"
    }

    private func detectSDCards() {
        let cards = sdCardDetector.getMountedSDCards()
        if let first = cards.first {
            selectedVolume = first
            scanVolume()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            selectedVolume = url.path
            scanVolume()
        }
    }

    private func scanVolume() {
        scanResult = cardScanner.scanVolume(at: selectedVolume)
    }

    private func performImport() {
        guard let result = scanResult else { return }

        isImporting = true
        importComplete = false
        importLog = []

        DispatchQueue.global(qos: .userInitiated).async {
            let importResult = fileImporter.performImport(
                rawFiles: result.rawFiles,
                jpegFiles: result.jpegFiles,
                sessionDate: sessionDate,
                baseImportsPath: appState.preferences.importsPath,
                progress: { message in
                    DispatchQueue.main.async {
                        importProgress = message
                        importLog.append(message)
                    }
                }
            )

            DispatchQueue.main.async {
                isImporting = false
                importComplete = true
                lastImportPath = importResult.destinationPath

                let summary = "✓ Import complete: \(importResult.rawCopied) RAW, \(importResult.jpegCopied) JPEG copied to \(importResult.sessionFolderName)"
                importLog.append(summary)

                if !importResult.errors.isEmpty {
                    importLog.append("⚠️ Errors:")
                    importLog.append(contentsOf: importResult.errors)
                }

                let session = ImportSession(
                    date: sessionDate,
                    sessionFolderName: importResult.sessionFolderName,
                    sourceVolumePath: selectedVolume,
                    rawCount: importResult.rawCopied,
                    jpegCount: importResult.jpegCopied,
                    destinationPath: importResult.destinationPath
                )
                appState.addImportSession(session)
            }
        }
    }
}
