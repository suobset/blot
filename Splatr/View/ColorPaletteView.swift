//
//  ColorPaletteView.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import SwiftUI
import AppKit

/// The main color palette showing foreground/background swatches,
/// a default color grid, and a button to show the custom colors palette.
struct ColorPaletteView: View {
    @ObservedObject var state = ToolPaletteState.shared
    @State private var showingColorPicker = false
    
    // Two rows of default colors reminiscent of classic palettes.
    let topColors: [Color] = [
        Color(nsColor: NSColor(red: 0, green: 0, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 0, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 128/255, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 128/255, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 128/255, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 0, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 0, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 128/255, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 64/255, blue: 64/255, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 0, blue: 255/255, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 128/255, blue: 255/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 0, blue: 255/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 0, blue: 64/255, alpha: 1)),
    ]
    
    let bottomColors: [Color] = [
        Color(nsColor: NSColor(red: 1, green: 1, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 192/255, green: 192/255, blue: 192/255, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 0, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 1, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 1, blue: 0, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 1, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 0, green: 0, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 0, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 1, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 1, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 1, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 128/255, green: 128/255, blue: 1, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 128/255, blue: 128/255, alpha: 1)),
        Color(nsColor: NSColor(red: 1, green: 128/255, blue: 1, alpha: 1)),
    ]
    
    var body: some View {
        HStack(spacing: 10) {
            // Foreground/Background color indicator
            ZStack(alignment: .topLeading) {
                Rectangle().fill(state.backgroundColor).frame(width: 20, height: 20)
                    .border(Color.primary.opacity(0.4), width: 1).offset(x: 10, y: 10)
                Rectangle().fill(state.foregroundColor).frame(width: 20, height: 20)
                    .border(Color.primary.opacity(0.6), width: 1)
            }
            .frame(width: 34, height: 34)
            .onTapGesture(count: 2) {
                // Double-click swaps colors.
                let temp = state.foregroundColor
                state.foregroundColor = state.backgroundColor
                state.backgroundColor = temp
            }
            .help("Double-click to swap colors")
            
            Divider().frame(height: 36)
            
            // Default color grid
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    ForEach(0..<14, id: \.self) { i in
                        ColorGridButton(color: topColors[i])
                    }
                }
                HStack(spacing: 1) {
                    ForEach(0..<14, id: \.self) { i in
                        ColorGridButton(color: bottomColors[i])
                    }
                }
            }
            
            Divider().frame(height: 36)
            
            // Custom colors button
            Button {
                ToolPaletteController.shared.toggleCustomColors()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 16))
                    Text("Custom")
                        .font(.caption2)
                }
                .frame(width: 44, height: 36)
            }
            .buttonStyle(.bordered)
            .help("Show custom colors palette")
        }
        .padding(10)
        .frame(height: 60)
    }
}

/// A default palette color swatch; left click sets foreground, Ctrl-click sets background.
struct ColorGridButton: View {
    let color: Color
    @ObservedObject var state = ToolPaletteState.shared
    
    var body: some View {
        Rectangle().fill(color).frame(width: 14, height: 14).border(Color.primary.opacity(0.2), width: 0.5)
            .onTapGesture { state.foregroundColor = color }
            .simultaneousGesture(TapGesture().modifiers(.control).onEnded { state.backgroundColor = color })
            .help("Left-click: foreground, Ctrl-click: background")
    }
}

#Preview {
    ColorPaletteView()
}
