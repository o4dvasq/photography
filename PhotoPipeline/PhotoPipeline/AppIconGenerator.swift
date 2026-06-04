//
//  AppIconGenerator.swift
//  PhotoPipeline
//
//  Programmatic app icon mockup - generates a simple placeholder icon
//  Run this once to create icon, then replace with professional design later
//
//  Usage: Create a macOS Command Line Tool target, add this code, run once to generate PNG
//

import SwiftUI
import AppKit

struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "E5E7EB"), Color(hex: "F9FAFB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 20) {
                // Retro camera icon
                ZStack {
                    // Camera body
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "4A5568"))
                        .frame(width: 120, height: 90)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                    // Lens
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "2D3748"), Color(hex: "1A202C")],
                                center: .center,
                                startRadius: 5,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)

                    // Lens ring
                    Circle()
                        .stroke(Color(hex: "CBD5E0"), lineWidth: 3)
                        .frame(width: 70, height: 70)

                    // Lens reflection
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .offset(x: -8, y: -8)

                    // Viewfinder window
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "1A202C"))
                        .frame(width: 15, height: 10)
                        .offset(x: 35, y: -30)
                }

                // Pipeline flow
                VStack(spacing: 8) {
                    // Flow arrows
                    HStack(spacing: 4) {
                        ForEach(0..<3) { _ in
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "3B82F6"), Color(hex: "8B5CF6")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }

                    // Output squares
                    HStack(spacing: 6) {
                        // RAW
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "3B82F6"))
                            .frame(width: 20, height: 20)

                        // JPEG
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(hex: "8B5CF6"))
                            .frame(width: 16, height: 16)
                    }
                }
            }
        }
        .frame(width: 512, height: 512)
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// Function to generate PNG (call this from a command-line tool or playground)
func generateAppIcon() {
    let view = AppIconView()
    let hosting = NSHostingController(rootView: view)
    hosting.view.frame = CGRect(x: 0, y: 0, width: 512, height: 512)

    guard let bitmapRep = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else { return }
    hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmapRep)

    guard let imageData = bitmapRep.representation(using: .png, properties: [:]) else { return }

    let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    let fileURL = desktopURL.appendingPathComponent("PhotoPipeline_Icon_512.png")

    try? imageData.write(to: fileURL)
    print("Icon saved to: \(fileURL.path)")
}
