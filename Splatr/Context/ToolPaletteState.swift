//
//  ToolPaletteState.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import AppKit
import Combine
import SwiftUI

/// Singleton observable state for tools/palettes used across the app.
/// This provides a single source of truth for the currently selected tool,
/// colors, brush attributes, text attributes, and navigator image.
class ToolPaletteState: ObservableObject {
    static let shared = ToolPaletteState()
    
    @Published var currentTool: Tool = .pencil
    @Published var brushSize: CGFloat = 4.0
    @Published var foregroundColor: Color = .black
    @Published var backgroundColor: Color = .white
    @Published var navigatorImage: NSImage?
    @Published var shapeStyle: ShapeStyle = .outline
    @Published var brushShape: BrushShape = .circle
    @Published var lineWidth: CGFloat = 1.0
    @Published var zoomLevel: CGFloat = 1.0
    
    // Custom colors (persisted)
    @Published var customColors: [Color] = [] {
        didSet { saveCustomColors() }
    }
    
    // Airbrush settings
    @Published var airbrushIntensity: CGFloat = 0.3
    
    // Text settings
    @Published var fontName: String = "Helvetica"
    @Published var fontSize: CGFloat = 24
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var isUnderlined: Bool = false
    
    private let customColorsKey = "BlotCustomColors"
    private let maxCustomColors = 28 // 2 rows of 14
    
    private init() {
        loadCustomColors()
    }
    
    /// Adds a custom color to the palette, avoiding duplicates and keeping
    /// the list bounded to `maxCustomColors`.
    func addCustomColor(_ color: Color) {
        // Don't add duplicates
        if customColors.contains(where: { colorsAreEqual($0, color) }) {
            return
        }
        
        // Add to front, remove oldest if at max
        customColors.insert(color, at: 0)
        if customColors.count > maxCustomColors {
            customColors.removeLast()
        }
    }
    
    /// Compares two SwiftUI Colors in deviceRGB space with a tolerance,
    /// to handle floating-point differences.
    private func colorsAreEqual(_ c1: Color, _ c2: Color) -> Bool {
        let ns1 = NSColor(c1).usingColorSpace(.deviceRGB)
        let ns2 = NSColor(c2).usingColorSpace(.deviceRGB)
        guard let ns1, let ns2 else { return false }
        return abs(ns1.redComponent - ns2.redComponent) < 0.01 &&
               abs(ns1.greenComponent - ns2.greenComponent) < 0.01 &&
               abs(ns1.blueComponent - ns2.blueComponent) < 0.01
    }
    
    /// Persists custom colors to UserDefaults as RGBA component arrays.
    private func saveCustomColors() {
        let colorData = customColors.compactMap { color -> [CGFloat]? in
            guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB) else { return nil }
            return [nsColor.redComponent, nsColor.greenComponent, nsColor.blueComponent, nsColor.alphaComponent]
        }
        UserDefaults.standard.set(colorData, forKey: customColorsKey)
    }
    
    /// Loads custom colors from UserDefaults.
    private func loadCustomColors() {
        guard let colorData = UserDefaults.standard.array(forKey: customColorsKey) as? [[CGFloat]] else { return }
        customColors = colorData.map { components in
            Color(nsColor: NSColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        }
    }
}
