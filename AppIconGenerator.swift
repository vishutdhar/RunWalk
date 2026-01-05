#!/usr/bin/env swift

import Cocoa
import SwiftUI

// App Icon Design: A circular icon with run (orange) and walk (green) segments
// representing the alternating interval concept

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color.black)

            // Orange arc (RUN - top half)
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(
                    Color.orange,
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(size * 0.12)

            // Green arc (WALK - bottom half)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: size * 0.15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(size * 0.12)

            // Center play icon
            Image(systemName: "figure.run")
                .font(.system(size: size * 0.35, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// Render and save the icon
func generateIcon() {
    let size: CGFloat = 1024

    let view = AppIconView(size: size)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 1.0

    if let nsImage = renderer.nsImage {
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {

            let url = URL(fileURLWithPath: "/Users/vishutdhar/Code/RunWalk/AppIcon.png")
            try? pngData.write(to: url)
            print("Icon saved to: \(url.path)")
        }
    }
}

generateIcon()
