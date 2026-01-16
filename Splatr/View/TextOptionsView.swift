//
//  TextOptionsView.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import SwiftUI

/// UI for choosing text font, size, styles, and previewing result.
/// Binds to the shared ToolPaletteState.
struct TextOptionsView: View {
    @ObservedObject var state = ToolPaletteState.shared
    
    /// A small curated font list for convenience.
    let availableFonts = [
        "Helvetica", "Helvetica Neue", "Arial", "Times New Roman",
        "Georgia", "Verdana", "Courier New", "Monaco",
        "Menlo", "SF Pro", "Avenir", "Futura",
        "Palatino", "Optima", "Gill Sans", "Baskerville"
    ].sorted()
    
    /// Common font sizes.
    let fontSizes: [CGFloat] = [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72, 96]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Font picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Font").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $state.fontName) {
                    ForEach(availableFonts, id: \.self) { font in
                        Text(font).font(.custom(font, size: 12)).tag(font)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            
            // Size picker + stepper
            VStack(alignment: .leading, spacing: 4) {
                Text("Size").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Picker("", selection: $state.fontSize) {
                        ForEach(fontSizes, id: \.self) { size in
                            Text("\(Int(size))").tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 70)
                    
                    Stepper("", value: $state.fontSize, in: 1...200, step: 1).labelsHidden()
                }
            }
            
            // Styles toggles
            VStack(alignment: .leading, spacing: 4) {
                Text("Style").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Toggle(isOn: $state.isBold) { Image(systemName: "bold") }
                        .toggleStyle(.button).help("Bold (⌘B)")
                    Toggle(isOn: $state.isItalic) { Image(systemName: "italic") }
                        .toggleStyle(.button).help("Italic (⌘I)")
                    Toggle(isOn: $state.isUnderlined) { Image(systemName: "underline") }
                        .toggleStyle(.button).help("Underline (⌘U)")
                }
            }
            
            // Live preview reflects current settings.
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview").font(.caption).foregroundStyle(.secondary)
                Text("AaBbCc")
                    .font(.custom(state.fontName, size: min(state.fontSize, 24)))
                    .fontWeight(state.isBold ? .bold : .regular)
                    .italic(state.isItalic)
                    .underline(state.isUnderlined)
                    .foregroundStyle(state.foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .frame(width: 180, height: 200)
    }
}

#Preview {
    TextOptionsView()
}
