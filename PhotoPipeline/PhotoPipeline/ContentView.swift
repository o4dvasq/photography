//
//  ContentView.swift
//  PhotoPipeline
//
//  Tab container: Import and Export
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .tag(0)

            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(1)
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToImportTab"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExportTab"))) { _ in
            selectedTab = 1
        }
    }
}
