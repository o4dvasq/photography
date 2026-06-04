//
//  PreferencesView.swift
//  PhotoPipeline
//
//  Preferences window (Cmd-,)
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Paths") {
                HStack {
                    Text("Base photography folder:")
                    TextField("", text: $appState.preferences.basePhotographyFolder)
                        .textFieldStyle(.roundedBorder)

                    Button("Choose...") {
                        chooseFolder()
                    }
                }

                Text("Imports: \(appState.preferences.importsPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Exports: \(appState.preferences.exportsPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Behavior") {
                Toggle("Auto-open app on SD card detection", isOn: $appState.preferences.autoOpenOnSDCard)
                Toggle("Show menubar icon", isOn: $appState.preferences.showMenubarIcon)
            }

            Section("Instagram Export") {
                Toggle("Strip GPS metadata", isOn: $appState.preferences.stripGPSMetadata)

                HStack {
                    Text("Long edge target (px):")
                    TextField("", value: $appState.preferences.instagramLongEdgeTarget, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }

                HStack {
                    Text("JPEG quality (1-100):")
                    TextField("", value: $appState.preferences.jpegExportQuality, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
        }
        .padding(20)
        .frame(width: 500)
        .onChange(of: appState.preferences) { _ in
            appState.savePreferences()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            appState.preferences.basePhotographyFolder = url.path
        }
    }
}
