//
//  SDCardDetector.swift
//  PhotoPipeline
//
//  NSWorkspace volume mount observer for SD card detection
//

import Foundation
import AppKit

class SDCardDetector {
    var onCardDetected: ((String) -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeDidMount(_:)),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func volumeDidMount(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let volume = userInfo["NSWorkspaceVolumeURLKey"] as? URL else {
            return
        }

        if isSDCard(volume) {
            onCardDetected?(volume.path)
        }
    }

    private func isSDCard(_ volumeURL: URL) -> Bool {
        guard let values = try? volumeURL.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey]) else {
            return false
        }

        let isRemovable = values.volumeIsRemovable ?? false
        let isEjectable = values.volumeIsEjectable ?? false

        return isRemovable && isEjectable
    }

    func getMountedSDCards() -> [String] {
        let mountedVolumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey], options: []) ?? []

        return mountedVolumes.filter { isSDCard($0) }.map { $0.path }
    }
}
