//
//  NavigatorView.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import SwiftUI

/// Displays a live preview of the current canvas (if provided by the editor),
/// typically scaled down, in a small floating panel.
struct NavigatorView: View {
    @ObservedObject var state = ToolPaletteState.shared
    
    var body: some View {
        VStack(spacing: 8) {
            if let image = state.navigatorImage {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 160, maxHeight: 120).border(Color.primary.opacity(0.2), width: 1)
            } else {
                Rectangle().fill(Color.secondary.opacity(0.1)).frame(width: 160, height: 120)
                    .overlay(Text("No canvas").font(.caption).foregroundStyle(.secondary))
            }
        }
        .padding(8)
        .frame(width: 180, height: 140)
    }
}

#Preview {
    NavigatorView()
}
