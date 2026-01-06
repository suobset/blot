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
    @State private var hasAppeared = false
    @State private var isResizingWindow = false
    @State private var pinchBaseZoom: CGFloat = 1.0
    @State private var cursorLocation: CGPoint = .zero
    @State private var scrollOffset: CGPoint = .zero
    
    private let canvasPadding: CGFloat = 20
    private let zoomLevels: [CGFloat] = [0.25, 0.5, 1, 2, 4, 6, 8]
    
    var body: some View {
        GeometryReader { geometry in
            canvasContainer(for: geometry)
                .background(Color(nsColor: canvasLockedToWindow ? .white : .controlBackgroundColor))
                .gesture(pinchZoomGesture)
                .onChange(of: geometry.size) { newSize in
                    handleGeometryChange(newSize)
                }
                .onAppear {
                    handleAppear(geometry)
                }
        }
        .toolbar { toolbar }
        .onAppear { ToolPaletteController.shared.showAllPalettes() }
        .modifier(CanvasNotificationsModifier(contentView: self))
        .sheet(isPresented: $showingResizeSheet) {
            ResizeCanvasSheet(
                width: $newWidth,
                height: $newHeight,
                onResize: { w, h in
                    canvasLockedToWindow = false
                    resizeDocumentCanvas(to: CGSize(width: w, height: h))
                }
            )
        }
    }
    
    // MARK: - Canvas Container
    
    @ViewBuilder
    private func canvasContainer(for geometry: GeometryProxy) -> some View {
        let canvasWidth = document.canvasSize.width * toolState.zoomLevel
        let canvasHeight = document.canvasSize.height * toolState.zoomLevel
        let availableWidth = canvasLockedToWindow ? geometry.size.width : geometry.size.width - (canvasPadding * 2)
        let availableHeight = canvasLockedToWindow ? geometry.size.height : geometry.size.height - (canvasPadding * 2)
        let needsScroll = canvasWidth > availableWidth || canvasHeight > availableHeight
        
        if canvasLockedToWindow {
            canvasContent(showResizeHandles: false)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .trackingMouse { location in
                    cursorLocation = location
                }
        } else if needsScroll {
            ZoomableScrollView(
                zoomLevel: toolState.zoomLevel,
                cursorLocation: cursorLocation,
                pinchBaseZoom: pinchBaseZoom
            ) {
                canvasContent(showResizeHandles: true)
                    .frame(width: canvasWidth + canvasPadding, height: canvasHeight + canvasPadding)
                    .padding(canvasPadding)
            }
            .trackingMouse { location in
                cursorLocation = location
            }
        } else {
            canvasContent(showResizeHandles: true)
                .frame(width: canvasWidth + canvasPadding, height: canvasHeight + canvasPadding)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .trackingMouse { location in
                    cursorLocation = location
                }
        }
    }
    
    // MARK: - Pinch Zoom Gesture
    
    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                if pinchBaseZoom == 1.0 && toolState.zoomLevel != 1.0 {
                    pinchBaseZoom = toolState.zoomLevel
                } else if pinchBaseZoom == 1.0 {
                    pinchBaseZoom = toolState.zoomLevel
                }
                let newZoom = pinchBaseZoom * scale
                toolState.zoomLevel = min(max(newZoom, 0.25), 8.0)
            }
            .onEnded { scale in
                let finalZoom = pinchBaseZoom * scale
                let clamped = min(max(finalZoom, 0.25), 8.0)
                if let nearest = zoomLevels.min(by: { abs($0 - clamped) < abs($1 - clamped) }),
                   abs(nearest - clamped) / clamped < 0.15 {
                    withAnimation(.easeOut(duration: 0.1)) {
                        toolState.zoomLevel = nearest
                    }
                }
                pinchBaseZoom = 1.0
            }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 8) {
                Button(action: toggleLock) {
                    Image(systemName: canvasLockedToWindow ? "lock.fill" : "lock.open")
                        .foregroundColor(canvasLockedToWindow ? .accentColor : .secondary)
                    Text(canvasLockedToWindow ? "Fit to Window" : "Custom Size")
                }
                .help(canvasLockedToWindow ? "Canvas resizes with window" : "Canvas size is independent of window")
                
                Divider()
                
                HStack(spacing: 4) {
                    Image(systemName: toolState.currentTool.icon)
                    Text(toolState.currentTool.rawValue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(6)
                
                Divider()
                
                zoomControlsView
                
                Text("\(Int(document.canvasSize.width)) × \(Int(document.canvasSize.height))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .controlSize(.large)
            .padding(.horizontal, 16)
        }
    }
    
    private var zoomControlsView: some View {
        HStack(spacing: 4) {
            Button { zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .disabled(toolState.zoomLevel <= zoomLevels.first!)
            
            Text("\(Int(toolState.zoomLevel * 100))%")
                .frame(minWidth: 40)
                .monospacedDigit()
            
            Button { zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .disabled(toolState.zoomLevel >= zoomLevels.last!)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
    
    // MARK: - Zoom Methods
    
    func zoomIn() {
        if let next = zoomLevels.first(where: { $0 > toolState.zoomLevel }) {
            withAnimation(.easeOut(duration: 0.15)) {
                toolState.zoomLevel = next
            }
        }
    }
    
    func zoomOut() {
        if let prev = zoomLevels.last(where: { $0 < toolState.zoomLevel }) {
            withAnimation(.easeOut(duration: 0.15)) {
                toolState.zoomLevel = prev
            }
        }
    }
    
    func resetZoom() {
        withAnimation(.easeOut(duration: 0.15)) {
            toolState.zoomLevel = 1.0
        }
    }
    
    // MARK: - Geometry Handlers
    
    private func handleGeometryChange(_ newSize: CGSize) {
        guard hasAppeared else { return }
        lastGeometrySize = newSize
        
        if canvasLockedToWindow {
            let newCanvasSize = CGSize(
                width: floor(max(1, newSize.width / toolState.zoomLevel)),
                height: floor(max(1, newSize.height / toolState.zoomLevel))
            )
            if abs(document.canvasSize.width - newCanvasSize.width) > 1 ||
               abs(document.canvasSize.height - newCanvasSize.height) > 1 {
                resizeDocumentCanvas(to: newCanvasSize)
            }
        }
    }
    
    private func handleAppear(_ geometry: GeometryProxy) {
        lastGeometrySize = geometry.size
        let isNewDocument = isDocumentNew()
        
        if isNewDocument {
            canvasLockedToWindow = true
            let initialSize = CGSize(
                width: floor(geometry.size.width / toolState.zoomLevel),
                height: floor(geometry.size.height / toolState.zoomLevel)
            )
            document.canvasSize = initialSize
            document.canvasData = splatrDocument.createBlankCanvas(size: initialSize)
        } else {
            canvasLockedToWindow = false
        }
        hasAppeared = true
    }
    
    // MARK: - Helper Methods
    
    private func isDocumentNew() -> Bool {
        guard document.canvasSize == splatrDocument.defaultSize else { return false }
        let blankData = splatrDocument.createBlankCanvas(size: splatrDocument.defaultSize)
        return document.canvasData == blankData
    }
    
    private func toggleLock() {
        if canvasLockedToWindow {
            canvasLockedToWindow = false
        } else {
            canvasLockedToWindow = true
            if let size = lastGeometrySize {
                let newCanvasSize = CGSize(
                    width: floor(size.width / toolState.zoomLevel),
                    height: floor(size.height / toolState.zoomLevel)
                )
                resizeDocumentCanvas(to: newCanvasSize)
            }
        }
    }
    
    func resizeDocumentCanvas(to newSize: CGSize) {
        let oldSize = document.canvasSize
        guard abs(oldSize.width - newSize.width) > 0.5 ||
              abs(oldSize.height - newSize.height) > 0.5 else { return }
        
        guard let oldImage = NSImage(data: document.canvasData) else {
            document.canvasSize = newSize
            document.canvasData = splatrDocument.createBlankCanvas(size: newSize)
            return
        }
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: newSize).fill()
        
        let drawWidth = min(oldSize.width, newSize.width)
        let drawHeight = min(oldSize.height, newSize.height)
        let sourceRect = NSRect(x: 0, y: oldSize.height - drawHeight, width: drawWidth, height: drawHeight)
        let destRect = NSRect(x: 0, y: newSize.height - drawHeight, width: drawWidth, height: drawHeight)
        oldImage.draw(in: destRect, from: sourceRect, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        
        if let tiffData = newImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            document.canvasSize = newSize
            document.canvasData = pngData
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
                resizeDocumentCanvas(to: newSize)
            },
            onCanvasUpdate: { image in
                toolState.navigatorImage = image
            }
        )
        .frame(width: document.canvasSize.width, height: document.canvasSize.height)
        .scaleEffect(toolState.zoomLevel, anchor: .topLeading)
    }
    
    // MARK: - Canvas Operations
    
    func flipCanvas(horizontal: Bool) {
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
    
    func invertCanvasColors() {
        guard let image = NSImage(data: document.canvasData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else { return }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorInvert")!
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let inverted = CIContext().createCGImage(output, from: output.extent) else { return }
        
        let newImage = NSImage(cgImage: inverted, size: image.size)
        if let tiff = newImage.tiffRepresentation,
           let bmp = NSBitmapImageRep(data: tiff),
           let png = bmp.representation(using: .png, properties: [:]) {
            document.canvasData = png
        }
    }
    
    func clearCanvas() {
        document.canvasData = splatrDocument.createBlankCanvas(size: document.canvasSize)
    }
    
    func showResizeSheet() {
        newWidth = "\(Int(document.canvasSize.width))"
        newHeight = "\(Int(document.canvasSize.height))"
        showingResizeSheet = true
    }
    
    func exportImage(as format: NSBitmapImageRep.FileType) {
        guard let image = NSImage(data: document.canvasData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [formatToUTType(format)]
        panel.nameFieldStringValue = "Untitled.\(formatExtension(format))"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
                if format == .jpeg { properties[.compressionFactor] = 0.9 }
                if let data = bitmap.representation(using: format, properties: properties) {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    func exportAsPDF() {
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

// MARK: - Notifications Modifier (keeps body clean)

struct CanvasNotificationsModifier: ViewModifier {
    let contentView: ContentView
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .zoomIn)) { _ in contentView.zoomIn() }
            .onReceive(NotificationCenter.default.publisher(for: .zoomOut)) { _ in contentView.zoomOut() }
            .onReceive(NotificationCenter.default.publisher(for: .zoomToFit)) { _ in contentView.resetZoom() }
            .onReceive(NotificationCenter.default.publisher(for: .resizeCanvas)) { _ in contentView.showResizeSheet() }
            .onReceive(NotificationCenter.default.publisher(for: .clearCanvas)) { _ in contentView.clearCanvas() }
            .onReceive(NotificationCenter.default.publisher(for: .flipHorizontal)) { _ in contentView.flipCanvas(horizontal: true) }
            .onReceive(NotificationCenter.default.publisher(for: .flipVertical)) { _ in contentView.flipCanvas(horizontal: false) }
            .onReceive(NotificationCenter.default.publisher(for: .invertColors)) { _ in contentView.invertCanvasColors() }
            .onReceive(NotificationCenter.default.publisher(for: .exportPNG)) { _ in contentView.exportImage(as: .png) }
            .onReceive(NotificationCenter.default.publisher(for: .exportJPEG)) { _ in contentView.exportImage(as: .jpeg) }
            .onReceive(NotificationCenter.default.publisher(for: .exportTIFF)) { _ in contentView.exportImage(as: .tiff) }
            .onReceive(NotificationCenter.default.publisher(for: .exportBMP)) { _ in contentView.exportImage(as: .bmp) }
            .onReceive(NotificationCenter.default.publisher(for: .exportGIF)) { _ in contentView.exportImage(as: .gif) }
            .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in contentView.exportAsPDF() }
    }
}

// MARK: - Zoom Notifications

extension Notification.Name {
    static let zoomIn = Notification.Name("zoomIn")
    static let zoomOut = Notification.Name("zoomOut")
    static let zoomToFit = Notification.Name("zoomToFit")
}

// MARK: - Resize Sheet

struct ResizeCanvasSheet: View {
    @Binding var width: String
    @Binding var height: String
    var onResize: (CGFloat, CGFloat) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Resize Canvas").font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Width:").frame(width: 60, alignment: .trailing)
                    TextField("", text: $width).textFieldStyle(.roundedBorder).frame(width: 80)
                    Text("pixels").foregroundStyle(.secondary).font(.caption)
                }
                HStack {
                    Text("Height:").frame(width: 60, alignment: .trailing)
                    TextField("", text: $height).textFieldStyle(.roundedBorder).frame(width: 80)
                    Text("pixels").foregroundStyle(.secondary).font(.caption)
                }
            }
            
            Text("Content will be anchored to top-left corner").font(.caption).foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
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

// MARK: - Mouse Tracking Modifier

struct MouseTrackingModifier: ViewModifier {
    let onMove: (CGPoint) -> Void
    
    func body(content: Content) -> some View {
        content.background(
            MouseTrackingView(onMove: onMove)
        )
    }
}

extension View {
    func trackingMouse(onMove: @escaping (CGPoint) -> Void) -> some View {
        modifier(MouseTrackingModifier(onMove: onMove))
    }
}

struct MouseTrackingView: NSViewRepresentable {
    let onMove: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingNSView)?.onMove = onMove
    }
    
    class TrackingNSView: NSView {
        var onMove: ((CGPoint) -> Void)?
        var trackingArea: NSTrackingArea?
        
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea {
                removeTrackingArea(existing)
            }
            trackingArea = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea!)
        }
        
        override func mouseMoved(with event: NSEvent) {
            let location = convert(event.locationInWindow, from: nil)
            onMove?(CGPoint(x: location.x, y: bounds.height - location.y))
        }
    }
}

// MARK: - Zoomable ScrollView (anchors zoom to cursor)

struct ZoomableScrollView<Content: View>: NSViewRepresentable {
    let zoomLevel: CGFloat
    let cursorLocation: CGPoint
    let pinchBaseZoom: CGFloat
    @ViewBuilder let content: Content
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        let documentView = NSView()
        documentView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])
        
        scrollView.documentView = documentView
        context.coordinator.scrollView = scrollView
        context.coordinator.lastZoom = zoomLevel
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Update content
        if let documentView = scrollView.documentView,
           let hostingView = documentView.subviews.first as? NSHostingView<Content> {
            hostingView.rootView = content
        }
        
        // Handle zoom change - anchor to cursor position
        let oldZoom = context.coordinator.lastZoom
        if abs(zoomLevel - oldZoom) > 0.001 {
            anchorZoom(scrollView: scrollView, oldZoom: oldZoom, newZoom: zoomLevel, context: context)
            context.coordinator.lastZoom = zoomLevel
        }
        
        // Update document view size
        DispatchQueue.main.async {
            if let documentView = scrollView.documentView,
               let hostingView = documentView.subviews.first as? NSHostingView<Content> {
                let fittingSize = hostingView.fittingSize
                documentView.frame.size = fittingSize
            }
        }
    }
    
    private func anchorZoom(scrollView: NSScrollView, oldZoom: CGFloat, newZoom: CGFloat, context: Context) {
        guard let clipView = scrollView.contentView as? NSClipView else { return }
        
        let visibleRect = clipView.documentVisibleRect
        
        // Cursor position relative to visible area
        let cursorInView = cursorLocation
        
        // Point in content coordinates at old zoom
        let contentX = visibleRect.origin.x + cursorInView.x
        let contentY = visibleRect.origin.y + cursorInView.y
        
        // Scale factor
        let scale = newZoom / oldZoom
        
        // New content position for the same point
        let newContentX = contentX * scale
        let newContentY = contentY * scale
        
        // New scroll origin to keep cursor over same content
        let newOriginX = newContentX - cursorInView.x
        let newOriginY = newContentY - cursorInView.y
        
        DispatchQueue.main.async {
            let newOrigin = CGPoint(
                x: max(0, newOriginX),
                y: max(0, newOriginY)
            )
            clipView.setBoundsOrigin(newOrigin)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var scrollView: NSScrollView?
        var lastZoom: CGFloat = 1.0
    }
}
