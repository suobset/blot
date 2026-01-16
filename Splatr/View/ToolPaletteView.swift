//
//  ToolPaletteView.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import SwiftUI

/// Grid of tool buttons and a compact options area that changes depending
/// on the selected tool (e.g., brush size, line width, shape style).
struct ToolPaletteView: View {
    @ObservedObject var state = ToolPaletteState.shared
    
    /// 8 rows × 2 columns to mirror classic MS Paint layout.
    let toolRows: [[Tool]] = [
        [.freeFormSelect, .rectangleSelect],
        [.eraser, .fill],
        [.colorPicker, .magnifier],
        [.pencil, .brush],
        [.airbrush, .text],
        [.line, .curve],
        [.rectangle, .polygon],
        [.ellipse, .roundedRectangle]
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            // Tool buttons
            ForEach(0..<toolRows.count, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(toolRows[row]) { tool in
                        ToolButton(tool: tool, isSelected: state.currentTool == tool) {
                            state.currentTool = tool
                        }
                    }
                }
            }
            
            Divider().padding(.vertical, 4)
            // Contextual options for the current tool
            toolOptionsView
            Spacer()
        }
        .padding(6)
        .frame(width: 66, height: 420)
    }
    
    /// Small contextual UI for the selected tool.
    @ViewBuilder
    var toolOptionsView: some View {
        switch state.currentTool {
        case .eraser, .airbrush:
            VStack(spacing: 2) {
                Text("Size").font(.caption2).foregroundStyle(.secondary)
                ForEach([2, 4, 6, 8], id: \.self) { size in
                    Button {
                        state.brushSize = CGFloat(size)
                    } label: {
                        Rectangle()
                            .fill(state.brushSize == CGFloat(size) ? Color.accentColor : Color.primary)
                            .frame(width: CGFloat(size * 3), height: CGFloat(size))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .brush:
            VStack(spacing: 2) {
                Text("Size: \(Int(state.brushSize.rounded(.down)))").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $state.brushSize, in: 2...20, step:1).frame(width: 50)
                Text("Shape").font(.caption2).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.fixed(20)), GridItem(.fixed(20))], spacing: 2) {
                    ForEach(BrushShape.allCases, id: \.rawValue) { shape in
                        Button { state.brushShape = shape } label: {
                            brushShapeIcon(shape).frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .background(state.brushShape == shape ? Color.accentColor.opacity(0.3) : Color.clear)
                        .cornerRadius(2)
                    }
                }
            }
        case .line, .curve:
            VStack(spacing: 2) {
                Text("Width").font(.caption2).foregroundStyle(.secondary)
                ForEach([1, 2, 3, 4, 5], id: \.self) { width in
                    Button { state.lineWidth = CGFloat(width) } label: {
                        Rectangle()
                            .fill(state.lineWidth == CGFloat(width) ? Color.accentColor : Color.primary)
                            .frame(width: 40, height: CGFloat(width))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .rectangle, .ellipse, .roundedRectangle, .polygon:
            VStack(spacing: 2) {
                Text("Style").font(.caption2).foregroundStyle(.secondary)
                ForEach(ShapeStyle.allCases, id: \.rawValue) { style in
                    Button { state.shapeStyle = style } label: {
                        shapeStyleIcon(style).frame(width: 40, height: 20)
                    }
                    .buttonStyle(.plain)
                    .background(state.shapeStyle == style ? Color.accentColor.opacity(0.3) : Color.clear)
                    .cornerRadius(2)
                }
            }
        case .magnifier:
            VStack(spacing: 2) {
                Text("Zoom").font(.caption2).foregroundStyle(.secondary)
                ForEach([1, 2, 4, 6, 8], id: \.self) { zoom in
                    Button { state.zoomLevel = CGFloat(zoom) } label: {
                        Text("\(zoom)×").font(.caption).frame(width: 36)
                    }
                    .buttonStyle(.bordered)
                    .tint(state.zoomLevel == CGFloat(zoom) ? .accentColor : .secondary)
                }
            }
        default:
            VStack(spacing: 4) {
                Text("Size: \(Int(state.brushSize))").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $state.brushSize, in: 1...20, step: 1).frame(width: 50)
            }
        }
    }
    
    /// Simple icons to visualize brush shapes.
    func brushShapeIcon(_ shape: BrushShape) -> some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3)
            switch shape {
            case .circle: context.fill(Circle().path(in: rect), with: .color(.primary))
            case .square: context.fill(Rectangle().path(in: rect), with: .color(.primary))
            case .slashRight:
                var path = Path()
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                context.stroke(path, with: .color(.primary), lineWidth: 2)
            case .slashLeft:
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                context.stroke(path, with: .color(.primary), lineWidth: 2)
            }
        }
    }
    
    /// Simple icons to visualize shape styles.
    func shapeStyleIcon(_ style: ShapeStyle) -> some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
            switch style {
            case .outline: context.stroke(Rectangle().path(in: rect), with: .color(.primary), lineWidth: 1)
            case .filledWithOutline:
                context.fill(Rectangle().path(in: rect), with: .color(.secondary))
                context.stroke(Rectangle().path(in: rect), with: .color(.primary), lineWidth: 1)
            case .filledNoOutline: context.fill(Rectangle().path(in: rect), with: .color(.primary))
            }
        }
    }
}

/// Small tool button with selection highlighting and help tooltip.
struct ToolButton: View {
    let tool: Tool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: tool.icon).font(.system(size: 14)).frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
        .help("\(tool.rawValue) (\(tool.shortcut))")
    }
}

#Preview {
    ToolPaletteView()
}
