//
//  PhotoPipelineApp.swift
//  PhotoPipeline
//
//  Main app entry point with menubar setup
//

import SwiftUI
import UserNotifications

@main
struct PhotoPipelineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var sdCardDetector: SDCardDetector?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestNotificationPermissions()
        setupSDCardDetection()
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func setupMenuBar() {
        guard AppState.shared.preferences.showMenubarIcon else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "Photo Pipeline")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Open Photo Pipeline", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Import from SD", action: #selector(showImportTab), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Export pending", action: #selector(showExportTab), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
    }

    private func setupSDCardDetection() {
        sdCardDetector = SDCardDetector()
        sdCardDetector?.onCardDetected = { volumePath in
            self.showSDCardNotification(volumePath: volumePath)
            self.badgeMenubarIcon()
        }
    }

    private func showSDCardNotification(volumePath: String) {
        let content = UNMutableNotificationContent()
        content.title = "SD card detected"
        content.body = "Open Photo Pipeline?"
        content.sound = .default
        content.userInfo = ["volumePath": volumePath]

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    private func badgeMenubarIcon() {
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "camera.fill.badge.ellipsis", accessibilityDescription: "Photo Pipeline - SD card detected")
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("Photo Pipeline") || $0.contentViewController != nil }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func showImportTab() {
        openMainWindow()
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToImportTab"), object: nil)
    }

    @objc private func showExportTab() {
        openMainWindow()
        NotificationCenter.default.post(name: NSNotification.Name("SwitchToExportTab"), object: nil)
    }
}
