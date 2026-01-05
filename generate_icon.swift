#!/usr/bin/env swift

import Cocoa

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

let context = NSGraphicsContext.current!.cgContext

// Background - full black square (fills entire icon area)
context.setFillColor(NSColor.black.cgColor)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Draw arcs
let center = CGPoint(x: size/2, y: size/2)
let radius = size * 0.35
let lineWidth = size * 0.12

// Orange arc (RUN) - left half
context.setStrokeColor(NSColor.orange.cgColor)
context.setLineWidth(lineWidth)
context.setLineCap(.round)
context.addArc(center: center, radius: radius, startAngle: .pi/2, endAngle: -.pi/2, clockwise: false)
context.strokePath()

// Green arc (WALK) - right half
context.setStrokeColor(NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0).cgColor)
context.addArc(center: center, radius: radius, startAngle: -.pi/2, endAngle: .pi/2, clockwise: false)
context.strokePath()

image.unlockFocus()

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    let outputPath = "/Users/vishutdhar/Code/RunWalk/RunWalk/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    try! pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✅ App icon saved to: \(outputPath)")
}
