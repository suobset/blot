//
//  NSImage+dominantColor.swift
//  WelcomeWindow
//
//  Created by Giorgi Tchelidze on 29.05.25.
//

import AppKit
import CoreImage

extension NSImage {
    func dominantColor(sampleCount: Int = 1000) -> NSColor? {
        var proposedRect = NSRect(origin: .zero, size: self.size)
        guard let cgImage = self.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            print("❌ Failed to create CGImage from NSImage")
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("❌ Failed to create CGContext")
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else {
            print("❌ No pixel data found")
            return nil
        }

        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var colorCount: [UInt32: Int] = [:]

        // swiftlint:disable identifier_name
        for _ in 0..<sampleCount {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            let offset = 4 * (y * width + x)

            let r = data[offset]
            let g = data[offset + 1]
            let b = data[offset + 2]
            let a = data[offset + 3]

            // Skip low-opacity pixels
            if a < 20 { continue }

            // Skip nearly black or white pixels
            if (r < 20 && g < 20 && b < 20) || (r > 235 && g > 235 && b > 235) {
                continue
            }

            let rgb = (UInt32(r) << 16) + (UInt32(g) << 8) + UInt32(b)
            colorCount[rgb, default: 0] += 1
        }

        guard let (rgb, _) = colorCount.max(by: { $0.value < $1.value }) else {
            print("⚠️ No dominant color found. Try increasing sample count or checking image content.")
            return nil
        }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        // swiftlint:enable identifier_name
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
    }
}
