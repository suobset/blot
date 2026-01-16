//
//  Tool.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import Foundation

/// Enumeration of all tools the app exposes, with display names,
/// SF Symbols icons, and shortcut string for help tooltips.
enum Tool: String, CaseIterable, Identifiable {
    case freeFormSelect = "Free-Form Select"
    case rectangleSelect = "Select"
    case eraser = "Eraser"
    case fill = "Fill"
    case colorPicker = "Pick Color"
    case magnifier = "Magnifier"
    case pencil = "Pencil"
    case brush = "Brush"
    case airbrush = "Airbrush"
    case text = "Text"
    case line = "Line"
    case curve = "Curve"
    case rectangle = "Rectangle"
    case polygon = "Polygon"
    case ellipse = "Ellipse"
    case roundedRectangle = "Rounded Rect"
    
    var id: String { rawValue }
    
    /// SF Symbols name to represent each tool in the palette UI.
    var icon: String {
        switch self {
        case .freeFormSelect: return "lasso"
        case .rectangleSelect: return "rectangle.dashed"
        case .eraser: return "eraser.fill"
        case .fill: return "drop.fill"
        case .colorPicker: return "eyedropper"
        case .magnifier: return "magnifyingglass"
        case .pencil: return "pencil"
        case .brush: return "paintbrush.fill"
        case .airbrush: return "sprinkler.and.droplets"
        case .text: return "textformat"
        case .line: return "line.diagonal"
        case .curve: return "scribble"
        case .rectangle: return "rectangle"
        case .polygon: return "pentagon"
        case .ellipse: return "circle"
        case .roundedRectangle: return "rectangle.roundedtop"
        }
    }
    
    /// Human-readable shortcut hint for tooltips (not used for actual key handling here).
    var shortcut: String {
        switch self {
        case .freeFormSelect: return "S"
        case .rectangleSelect: return "⇧S"
        case .eraser: return "E"
        case .fill: return "G"
        case .colorPicker: return "I"
        case .magnifier: return "Z"
        case .pencil: return "P"
        case .brush: return "B"
        case .airbrush: return "A"
        case .text: return "T"
        case .line: return "L"
        case .curve: return "C"
        case .rectangle: return "R"
        case .polygon: return "Y"
        case .ellipse: return "O"
        case .roundedRectangle: return "⇧R"
        }
    }
}
