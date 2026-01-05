//
//  ContentView.swift
//  splatr
//
//  Created by Kushagra Srivastava on 1/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: splatrDocument
    @ObservedObject var toolState = ToolPaletteState.shared
    @State private var showingResizeSheet = false
    @State private var newWidth: String = ""
    @State private var newHeight: String = ""
    @State private var canvasLockedToWindow = true
    @State private var lastGeometrySize: CGSize? = nil
    @State private var pendingResize: CGSize? = nil
    
    private let canvasPadding: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            let canvasWidth = document.canvasSize.width * toolState.zoomLevel
            let canvasHeight = document.canvasSize.height * toolState.zoomLevel
            
            // When unlocked, account for padding and resize handle space
            let availableWidth = canvasLockedToWindow ? geometry.size.width : geometry.size.width - (canvasPadding * 2)
            let availableHeight = canvasLockedToWindow ? geometry.size.height : geometry.size.height - (canvasPadding * 2)
            let needsScroll = canvasWidth > availableWidth || canvasHeight > availableHeight
            
            Group {
                if canvasLockedToWindow {
                    // Locked: edge-to-edge, no scroll
                    canvasContent(showResizeHandles: false)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if needsScroll {
                    // Unlocked + canvas larger than window: scrollable with padding
                    ScrollView([.horizontal, .vertical]) {
                        canvasContent(showResizeHandles: true)
                            .frame(width: canvasWidth + canvasPadding, height: canvasHeight + canvasPadding)
                            .padding(canvasPadding)
                    }
                } else {
                    // Unlocked + canvas fits: centered with padding
                    canvasContent(showResizeHandles: true)
                        .frame(width: canvasWidth + canvasPadding, height: canvasHeight + canvasPadding)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .background(Color(nsColor: canvasLockedToWindow ? .white : .controlBackgroundColor))
            .onChange(of: geometry.size) { newSize in
                if canvasLockedToWindow {
                    pendingResize = newSize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if pendingResize == newSize {
                            let newCanvasWidth = max(1, newSize.width / toolState.zoomLevel)
                            let newCanvasHeight = max(1, newSize.height / toolState.zoomLevel)
                            document.canvasSize = CGSize(width: floor(newCanvasWidth), height: floor(newCanvasHeight))
                            pendingResize = nil
                        }
                    }
                }
                lastGeometrySize = newSize
            }
            .onAppear {
                // Check if document has a real image (not default blank)
                let isDefaultSize = document.canvasSize == CGSize(width: 800, height: 600)
                
                if isDefaultSize && canvasLockedToWindow {
                    // New document: size to window
                    let initialWidth = floor(geometry.size.width / toolState.zoomLevel)
                    let initialHeight = floor(geometry.size.height / toolState.zoomLevel)
                    document.canvasSize = CGSize(width: initialWidth, height: initialHeight)
                } else if !isDefaultSize {
                    // Opening existing image: unlock and use image dimensions
                    canvasLockedToWindow = false
                }
                lastGeometrySize = geometry.size
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 8) {
                    // Lock/Unlock button
                    Button(action: {
                        canvasLockedToWindow.toggle()
                        if canvasLockedToWindow, let size = lastGeometrySize {
                            let newCanvasWidth = floor(size.width / toolState.zoomLevel)
                            let newCanvasHeight = floor(size.height / toolState.zoomLevel)
                            document.canvasSize = CGSize(width: newCanvasWidth, height: newCanvasHeight)
                        }
                    }) {
                        Image(systemName: canvasLockedToWindow ? "lock.fill" : "lock.open")
                            .foregroundColor(canvasLockedToWindow ? .accentColor : .secondary)
                        Text(canvasLockedToWindow ? "Fit to Window" : "Custom Size")
                    }
                    .help(canvasLockedToWindow ? "Canvas resizes with window" : "Canvas size is independent of window")
                    
                    Divider()
                    
                    // Current tool indicator
                    HStack(spacing: 4) {
                        Image(systemName: toolState.currentTool.icon)
                        Text(toolState.currentTool.rawValue)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)
                    
                    Divider()
                    
                    // Zoom indicator
                    if toolState.zoomLevel != 1 {
                        Text("\(Int(toolState.zoomLevel * 100))%")
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    // Canvas size
                    Text("\(Int(document.canvasSize.width)) × \(Int(document.canvasSize.height))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)  // Makes all text smaller
                .controlSize(.large)  // Makes controls larger
                .padding(.horizontal, 16) // Increase padding for liquid glass
            }
        }
        .onAppear {
            ToolPaletteController.shared.showAllPalettes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resizeCanvas)) { _ in
            newWidth = "\(Int(document.canvasSize.width))"
            newHeight = "\(Int(document.canvasSize.height))"
            showingResizeSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in
            document.canvasData = splatrDocument.createBlankCanvas(size: document.canvasSize)
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipHorizontal)) { _ in
            flipCanvas(horizontal: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .flipVertical)) { _ in
            flipCanvas(horizontal: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: .invertColors)) { _ in
            invertCanvasColors()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPNG)) { _ in
            exportImage(as: .png)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportJPEG)) { _ in
            exportImage(as: .jpeg)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportTIFF)) { _ in
            exportImage(as: .tiff)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportBMP)) { _ in
            exportImage(as: .bmp)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportGIF)) { _ in
            exportImage(as: .gif)
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in
            exportAsPDF()
        }
        .sheet(isPresented: $showingResizeSheet) {
            ResizeCanvasSheet(
                width: $newWidth,
                height: $newHeight,
                onResize: { w, h in
                    canvasLockedToWindow = false
                    document.canvasSize = CGSize(width: w, height: h)
                }
            )
        }
    }
    
    // MARK: - Canvas Content
    
    private func canvasContent(showResizeHandles: Bool) -> some View {
        CanvasView(
            document: $document,
            currentColor: NSColor(toolState.foregroundColor),
            brushSize: toolState.brushSize,
            currentTool: toolState.currentTool,
            showResizeHandles: showResizeHandles,
            onCanvasResize: { newSize in
                canvasLockedToWindow = false
            },
            onCanvasUpdate: { image in
                toolState.navigatorImage = image
            }
        )
        .frame(
            width: document.canvasSize.width,
            height: document.canvasSize.height
        )
        .scaleEffect(toolState.zoomLevel, anchor: .topLeading)
    }
    
    // MARK: - Canvas Operations
    
    private func flipCanvas(horizontal: Bool) {
        guard let image = NSImage(data: document.canvasData) else { return }
        
        let newImage = NSImage(size: image.size)
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        if horizontal {
            transform.translateX(by: image.size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        } else {
            transform.translateX(by: 0, yBy: image.size.height)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()
        
        image.draw(in: NSRect(origin: .zero, size: image.size))
        newImage.unlockFocus()
        
        if let tiff = newImage.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            document.canvasData = png
        }
    }
    
    private func invertCanvasColors() {
        guard let image = NSImage(data: document.canvasData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorInvert")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let output = filter.outputImage else { return }
        
        let context = CIContext()
        guard let inverted = context.createCGImage(output, from: output.extent) else { return }
        
        let newImage = NSImage(cgImage: inverted, size: image.size)
        
        if let tiff = newImage.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            document.canvasData = png
        }
    }
    
    private func exportImage(as format: NSBitmapImageRep.FileType) {
        guard let image = NSImage(data: document.canvasData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [formatToUTType(format)]
        panel.nameFieldStringValue = "Untitled.\(formatExtension(format))"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
                if format == .jpeg {
                    properties[.compressionFactor] = 0.9
                }
                
                if let data = bitmap.representation(using: format, properties: properties) {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    private func exportAsPDF() {
        guard let image = NSImage(data: document.canvasData) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Untitled.pdf"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let pdfData = NSMutableData()
                guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return }
                
                var rect = CGRect(origin: .zero, size: document.canvasSize)
                guard let context = CGContext(consumer: consumer, mediaBox: &rect, nil) else { return }
                
                context.beginPDFPage(nil)
                
                if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    context.draw(cgImage, in: rect)
                }
                
                context.endPDFPage()
                context.closePDF()
                
                try? pdfData.write(to: url)
            }
        }
    }
    
    private func formatToUTType(_ format: NSBitmapImageRep.FileType) -> UTType {
        switch format {
        case .png: return .png
        case .jpeg, .jpeg2000: return .jpeg
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        default: return .png
        }
    }
    
    private func formatExtension(_ format: NSBitmapImageRep.FileType) -> String {
        switch format {
        case .png: return "png"
        case .jpeg, .jpeg2000: return "jpg"
        case .tiff: return "tiff"
        case .bmp: return "bmp"
        case .gif: return "gif"
        default: return "png"
        }
    }
}

struct ResizeCanvasSheet: View {
    @Binding var width: String
    @Binding var height: String
    var onResize: (CGFloat, CGFloat) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var maintainAspectRatio = false
    @State private var originalAspectRatio: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Resize Canvas")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Width:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("pixels")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                HStack {
                    Text("Height:")
                        .frame(width: 60, alignment: .trailing)
                    TextField("", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("pixels")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            
            Text("Content will be anchored to top-left corner")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Resize") {
                    if let w = Double(width), let h = Double(height),
                       w > 0, h > 0, w <= 8192, h <= 8192 {
                        onResize(CGFloat(w), CGFloat(h))
                    }
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 300)
    }
}

#Preview {
    ContentView(document: .constant(splatrDocument()))
}
