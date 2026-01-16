//
//  CustomColorsPaletteView.swift
//  splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import SwiftUI
import AppKit

/// A ColorPicker that automatically saves newly chosen colors into the shared
/// custom colors list (with duplicate suppression).
struct ColorPickerWithCustomSave: View {
    @Binding var selection: Color
    @ObservedObject var state = ToolPaletteState.shared
    @State private var previousColor: Color = .black
    
    var body: some View {
        ColorPicker("", selection: $selection)
            .labelsHidden()
            .onChange(of: selection) { newColor in
                // Add to custom colors when user picks a new color
                // (only if it's different from the previous one)
                if !colorsAreEqual(newColor, previousColor) {
                    state.addCustomColor(newColor)
                    previousColor = newColor
                }
            }
            .onAppear {
                previousColor = selection
            }
    }
    
    /// Local color equality with a tolerance to avoid noisy re-saves.
    private func colorsAreEqual(_ c1: Color, _ c2: Color) -> Bool {
        let ns1 = NSColor(c1).usingColorSpace(.deviceRGB)
        let ns2 = NSColor(c2).usingColorSpace(.deviceRGB)
        guard let ns1, let ns2 else { return false }
        return abs(ns1.redComponent - ns2.redComponent) < 0.01 &&
               abs(ns1.greenComponent - ns2.greenComponent) < 0.01 &&
               abs(ns1.blueComponent - ns2.blueComponent) < 0.01
    }
}

/// A compact palette that shows up to 28 custom colors in two rows,
/// with a ColorPicker to add new ones and a button to clear all.
struct CustomColorsPaletteView: View {
    @ObservedObject var state = ToolPaletteState.shared
    
    private let columns = 14
    
    var body: some View {
        VStack(spacing: 10) {
            // Color picker row
            HStack(spacing: 8) {
                Text("Pick Color:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ColorPickerWithCustomSave(selection: $state.foregroundColor)
                
                Spacer()
                
                Text("\(state.customColors.count)/28")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            
            Divider()
            
            // Custom colors grid
            if state.customColors.isEmpty {
                VStack(spacing: 4) {
                    Text("No custom colors yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Use the color picker above to add colors")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(height: 32)
            } else {
                VStack(spacing: 1) {
                    // First row
                    HStack(spacing: 1) {
                        ForEach(0..<columns, id: \.self) { i in
                            if i < state.customColors.count {
                                CustomColorGridButton(color: state.customColors[i], index: i)
                            } else {
                                EmptyColorSlot()
                            }
                        }
                    }
                    // Second row
                    HStack(spacing: 1) {
                        ForEach(0..<columns, id: \.self) { i in
                            let index = i + columns
                            if index < state.customColors.count {
                                CustomColorGridButton(color: state.customColors[index], index: index)
                            } else {
                                EmptyColorSlot()
                            }
                        }
                    }
                }
            }
            
            // Clear button
            HStack {
                Spacer()
                Button("Clear All") {
                    state.customColors.removeAll()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(state.customColors.isEmpty)
            }
        }
        .padding(10)
        .frame(width: 260, height: 110)
    }
}

/// An interactive color swatch that can set foreground (left click),
/// background (Ctrl-click), or be removed via context menu.
struct CustomColorGridButton: View {
    let color: Color
    let index: Int
    @ObservedObject var state = ToolPaletteState.shared
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 14, height: 14)
            .border(Color.primary.opacity(0.3), width: 0.5)
            .onTapGesture {
                state.foregroundColor = color
            }
            .simultaneousGesture(
                TapGesture().modifiers(.control).onEnded {
                    state.backgroundColor = color
                }
            )
            .contextMenu {
                Button("Set as Foreground") {
                    state.foregroundColor = color
                }
                Button("Set as Background") {
                    state.backgroundColor = color
                }
                Divider()
                Button("Remove", role: .destructive) {
                    state.customColors.remove(at: index)
                }
            }
            .help("Left-click: foreground, Ctrl-click: background, Right-click: options")
    }
}

/// Empty placeholder slot for the custom colors grid.
struct EmptyColorSlot: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(width: 14, height: 14)
            .border(Color.primary.opacity(0.1), width: 0.5)
    }
}

#Preview {
    CustomColorsPaletteView()
}
