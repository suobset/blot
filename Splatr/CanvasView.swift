//
//  CanvasView.swift
//  splatr
//
//  Created by Kushagra Srivastava on 1/2/26.
//

import SwiftUI
import AppKit

/// SwiftUI wrapper for an AppKit-based canvas view that handles pixel drawing,
/// tools (pencil, brush, eraser, airbrush, shapes, selection, text, color picker),
/// resize handles, and undo integration. The view synchronizes with the document
/// model and notifies the Navigator palette of updates.
struct CanvasView: NSViewRepresentable {
    @Binding var document: splatrDocument
    /// Foreground drawing color (converted from SwiftUI Color by the caller).
    var currentColor: NSColor
    /// Base brush size (interpreted per tool).
    var brushSize: CGFloat
    /// Currently selected tool from the shared tool palette state.
    var currentTool: Tool
    /// Whether to render resize handles and accept resize drags.
    var showResizeHandles: Bool
    /// Callback to request a canvas resize (delegated to ContentView).
    var onCanvasResize: (CGSize) -> Void
    /// Callback to update the Navigator image after changes.
    var onCanvasUpdate: (NSImage) -> Void
    /// Undo manager injected from SwiftUI environment for registration.
    @Environment(\.undoManager) var undoManager
    
    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.delegate = context.coordinator
        view.currentColor = currentColor
        view.brushSize = brushSize
        view.currentTool = currentTool
        view.showResizeHandles = showResizeHandles
        
        // Load from document - document is source of truth
        // Notify navigator on initial load
        view.reloadFromDocument(data: document.canvasData, size: document.canvasSize, notifyNavigator: true)
        return view
    }
    
    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        // Keep undo manager up-to-date for new windows/contexts.
        context.coordinator.undoManager = undoManager
        
        // Propagate tool and UI state into the NSView.
        nsView.currentColor = currentColor
        nsView.brushSize = brushSize
        nsView.currentTool = currentTool
        nsView.showResizeHandles = showResizeHandles
        
        // Detect external document changes (undo/redo/clear/flip/etc.) and reload image.
        if nsView.documentDataHash != document.canvasData.hashValue ||
           nsView.canvasSize != document.canvasSize {
            // Don't notify during update - just reload the image
            nsView.reloadFromDocument(data: document.canvasData, size: document.canvasSize, notifyNavigator: false)
        }
        
        // Request a redraw to reflect any state changes.
        nsView.setNeedsDisplay(nsView.bounds)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(document: $document, undoManager: undoManager, onCanvasResize: onCanvasResize, onCanvasUpdate: onCanvasUpdate)
    }
    
    /// Mediates between the NSView and SwiftUI: writes to the document binding,
    /// registers undo, and forwards callbacks to ContentView.
    class Coordinator {
        var document: Binding<splatrDocument>
        var undoManager: UndoManager?
        var onCanvasResize: (CGSize) -> Void
        var onCanvasUpdate: (NSImage) -> Void
        
        init(document: Binding<splatrDocument>, undoManager: UndoManager?, onCanvasResize: @escaping (CGSize) -> Void, onCanvasUpdate: @escaping (NSImage) -> Void) {
            self.document = document
            self.undoManager = undoManager
            self.onCanvasResize = onCanvasResize
            self.onCanvasUpdate = onCanvasUpdate
        }
        
        /// Saves new image data into the document and updates the Navigator without undo registration.
        func saveToDocument(_ data: Data, image: NSImage) {
            document.wrappedValue.canvasData = data
            onCanvasUpdate(image)
        }
        
        /// Requests the outer SwiftUI view to perform a canvas resize.
        func requestCanvasResize(_ size: CGSize) {
            onCanvasResize(size)
        }
        
        /// Updates the shared foreground color after a color pick operation.
        func colorPicked(_ color: NSColor) {
            DispatchQueue.main.async {
                ToolPaletteState.shared.foregroundColor = Color(nsColor: color)
            }
        }
        
        /// Saves new image data into the document and registers an undo operation.
        func saveWithUndo(newData: Data, image: NSImage, actionName: String) {
            guard let undoManager = undoManager else {
                saveToDocument(newData, image: image)
                return
            }
            
            let oldData = document.wrappedValue.canvasData
            guard oldData != newData else { return }
            
            // Register undo to restore previous canvas data and navigator image.
            undoManager.registerUndo(withTarget: self) { [weak self] _ in
                guard let self = self else { return }
                self.document.wrappedValue.canvasData = oldData
                if let img = NSImage(data: oldData) {
                    self.onCanvasUpdate(img)
                }
            }
            undoManager.setActionName(actionName)
            
            document.wrappedValue.canvasData = newData
            onCanvasUpdate(image)
        }
    }
}

/// AppKit canvas view that performs pixel-level drawing and previews.
/// The view maintains an NSImage as backing store and draws previews for
/// in-progress strokes, shapes, selections, etc. It communicates changes
/// back through the CanvasView.Coordinator.
class CanvasNSView: NSView {
    weak var delegate: CanvasView.Coordinator?
    
    // Canvas state - derived from document
    private var canvasImage: NSImage?
    var canvasSize: CGSize = CGSize(width: 800, height: 600)
    /// Hash of the last saved document data to detect external changes.
    var documentDataHash: Int = 0
    
    // Tool state
    var currentColor: NSColor = .black
    var brushSize: CGFloat = 4.0
    var currentTool: Tool = .pencil {
        didSet {
            // Remember the tool we came from when switching into the color picker
            if currentTool == .colorPicker, oldValue != .colorPicker {
                previousToolBeforePicker = oldValue
            }
        }
    }
    private var previousToolBeforePicker: Tool? = nil
    /// Controls whether resize handles are drawn and interactive.
    var showResizeHandles: Bool = true
    
    // Drawing state (for strokes)
    private var currentPath: [NSPoint] = []
    private var lastPoint: NSPoint?
    
    // Shape tools (rectangle, ellipse, rounded rect, line)
    private var shapeStartPoint: NSPoint?
    private var shapeEndPoint: NSPoint?
    
    // Curve tool (quadratic-like using two control phases)
    private var curveBaseStart: NSPoint?
    private var curveBaseEnd: NSPoint?
    private var curveControlPoint1: NSPoint?
    private var curvePhase: Int = 0
    
    // Polygon tool
    private var polygonPoints: [NSPoint] = []
    
    // Selection tools
    private var selectionRect: NSRect?
    private var selectionImage: NSImage?
    private var originalSelectionRect: NSRect?
    private var isMovingSelection = false
    private var selectionOffset: NSPoint = .zero
    private var freeFormPath: [NSPoint] = []
    // New: true free-form selection path and tracking of its position
    private var selectionPath: NSBezierPath?
    private var lastSelectionOrigin: NSPoint?
    
    // Text tool
    private var textField: NSTextField?
    private var textInsertPoint: NSPoint?
    
    // Resize handles
    private var isResizing = false
    private var resizeEdge: ResizeEdge = .none
    private var resizeStartSize: CGSize = .zero
    private let handleSize: CGFloat = 8
    
    // Airbrush
    private var airbrushTimer: Timer?
    private var airbrushLocation: NSPoint = .zero
    private var isAirbrushActive = false
    
    /// Which handle/edge is being dragged during a resize gesture.
    enum ResizeEdge {
        case none, right, bottom, corner
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    /// Expand intrinsic size to include resize handle extents so SwiftUI can lay out correctly.
    override var intrinsicContentSize: NSSize {
        NSSize(width: canvasSize.width + (showResizeHandles ? handleSize : 0),
               height: canvasSize.height + (showResizeHandles ? handleSize : 0))
    }
    
    // MARK: - Document Loading
    
    /// Reload canvas from document data - this is the ONLY way to set canvas content
    /// from the outside. It constructs an NSImage of the document size and optionally
    /// notifies the Navigator with the new image.
    func reloadFromDocument(data: Data, size: CGSize, notifyNavigator: Bool = true) {
        documentDataHash = data.hashValue
        canvasSize = size
        
        if data.isEmpty {
            createBlankCanvas()
            return
        }
        
        if let image = NSImage(data: data) {
            // Ensure image is rendered at correct size (clear background to white).
            let sizedImage = NSImage(size: size)
            sizedImage.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.draw(in: NSRect(origin: .zero, size: size))
            sizedImage.unlockFocus()
            canvasImage = sizedImage
            
            // Only notify navigator if not during a view update
            if notifyNavigator {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.onCanvasUpdate(sizedImage)
                }
            }
        } else {
            createBlankCanvas()
        }
        
        invalidateIntrinsicContentSize()
        setNeedsDisplay(bounds)
    }
    
    /// Creates a white background image for the current canvas size.
    private func createBlankCanvas() {
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        image.unlockFocus()
        canvasImage = image
    }
    
    // MARK: - Drawing
    
    /// Main draw routine: paints the canvas background, the backing image,
    /// and all in-progress previews (stroke, shapes, selections, etc.).
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Canvas background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        
        // Main image
        canvasImage?.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        // Previews
        drawCurrentStroke()
        drawShapePreview()
        drawCurvePreview()
        drawPolygonPreview()
        drawSelection()
        
        if showResizeHandles {
            drawResizeHandles()
        }
    }
    
    /// Renders the temporary stroke preview as the user drags with pencil/brush/eraser.
    private func drawCurrentStroke() {
        guard currentPath.count > 0 else { return }
        
        let drawColor = currentTool == .eraser ? NSColor.white : currentColor
        let drawSize = getDrawSize()
        
        drawColor.setStroke()
        drawColor.setFill()
        
        if currentPath.count == 1 {
            let point = currentPath[0]
            NSBezierPath(ovalIn: NSRect(x: point.x - drawSize/2, y: point.y - drawSize/2,
                                        width: drawSize, height: drawSize)).fill()
        } else {
            let path = NSBezierPath()
            path.lineWidth = drawSize
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: currentPath[0])
            for i in 1..<currentPath.count {
                path.line(to: currentPath[i])
            }
            path.stroke()
        }
    }
    
    /// Renders previews for line/rectangle/ellipse/rounded-rectangle as the user drags.
    private func drawShapePreview() {
        guard let start = shapeStartPoint, let end = shapeEndPoint else { return }
        guard [.line, .rectangle, .ellipse, .roundedRectangle].contains(currentTool) else { return }
        
        currentColor.setStroke()
        let lineWidth = ToolPaletteState.shared.lineWidth
        let rect = rectFromPoints(start, end)
        
        switch currentTool {
        case .line:
            let path = NSBezierPath()
            path.lineWidth = lineWidth
            path.move(to: start)
            path.line(to: end)
            path.stroke()
            
        case .rectangle:
            drawStyledShape(NSBezierPath(rect: rect), lineWidth: lineWidth)
            
        case .ellipse:
            drawStyledShape(NSBezierPath(ovalIn: rect), lineWidth: lineWidth)
            
        case .roundedRectangle:
            let radius = min(rect.width, rect.height) * 0.25
            drawStyledShape(NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius), lineWidth: lineWidth)
            
        default: break
        }
    }
    
    /// Renders preview for the curve tool, progressing through phases as control points are chosen.
    private func drawCurvePreview() {
        guard currentTool == .curve else { return }
        
        currentColor.setStroke()
        let lineWidth = ToolPaletteState.shared.lineWidth
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        
        if curvePhase == 0, let start = shapeStartPoint, let end = shapeEndPoint {
            path.move(to: start)
            path.line(to: end)
            path.stroke()
        } else if curvePhase >= 1, let start = curveBaseStart, let end = curveBaseEnd {
            path.move(to: start)
            let cp1 = curveControlPoint1 ?? start
            let cp2 = shapeEndPoint ?? end
            if curvePhase == 1 {
                path.curve(to: end, controlPoint1: cp1, controlPoint2: cp1)
            } else {
                path.curve(to: end, controlPoint1: cp1, controlPoint2: cp2)
            }
            path.stroke()
        }
    }
    
    /// Renders preview for polygon tool as points are added and mouse moves.
    private func drawPolygonPreview() {
        guard currentTool == .polygon, polygonPoints.count > 0 else { return }
        
        currentColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = ToolPaletteState.shared.lineWidth
        
        path.move(to: polygonPoints[0])
        for i in 1..<polygonPoints.count {
            path.line(to: polygonPoints[i])
        }
        if let end = shapeEndPoint {
            path.line(to: end)
        }
        path.stroke()
    }
    
    /// Draws selection rectangle/image and free-form selection outline.
    private func drawSelection() {
        // In-progress freehand path drawing (before capture)
        if currentTool == .freeFormSelect && freeFormPath.count > 1 && selectionImage == nil && selectionPath == nil {
            NSColor.gray.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1
            path.setLineDash([2, 2], count: 2, phase: 0)
            path.move(to: freeFormPath[0])
            for i in 1..<freeFormPath.count {
                path.line(to: freeFormPath[i])
            }
            path.stroke()
        }
        
        // Draw selection image if present
        if let rect = selectionRect, let selImage = selectionImage {
            selImage.draw(in: rect, from: NSRect(origin: .zero, size: rect.size), operation: .sourceOver, fraction: 1.0)
        }
        
        // Draw marching ants: prefer free-form path if available, else rect
        if let path = selectionPath {
            let ants = path.copy() as! NSBezierPath
            ants.lineWidth = 1
            NSColor.white.setStroke()
            ants.stroke()
            let phase = CGFloat(CACurrentMediaTime() * 10).truncatingRemainder(dividingBy: 8)
            ants.setLineDash([4, 4], count: 2, phase: phase)
            NSColor.black.setStroke()
            ants.stroke()
        } else if let rect = selectionRect {
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            NSColor.white.setStroke()
            path.stroke()
            path.setLineDash([4, 4], count: 2, phase: CGFloat(CACurrentMediaTime() * 10).truncatingRemainder(dividingBy: 8))
            NSColor.black.setStroke()
            path.stroke()
        }
    }
    
    /// Draws right, bottom, and corner resize handles next to the canvas.
    private func drawResizeHandles() {
        NSColor.controlAccentColor.setFill()
        
        NSBezierPath(roundedRect: NSRect(x: canvasSize.width, y: canvasSize.height/2 - 4, width: 6, height: 8),
                     xRadius: 2, yRadius: 2).fill()
        NSBezierPath(roundedRect: NSRect(x: canvasSize.width/2 - 4, y: -6, width: 8, height: 6),
                     xRadius: 2, yRadius: 2).fill()
        NSBezierPath(roundedRect: NSRect(x: canvasSize.width, y: -6, width: 6, height: 6),
                     xRadius: 2, yRadius: 2).fill()
    }
    
    /// Applies style (outline/filled) to a shape path for preview drawing.
    private func drawStyledShape(_ path: NSBezierPath, lineWidth: CGFloat) {
        path.lineWidth = lineWidth
        let style = ToolPaletteState.shared.shapeStyle
        
        switch style {
        case .outline:
            currentColor.setStroke()
            path.stroke()
        case .filledWithOutline:
            NSColor(ToolPaletteState.shared.backgroundColor).setFill()
            path.fill()
            currentColor.setStroke()
            path.stroke()
        case .filledNoOutline:
            currentColor.setFill()
            path.fill()
        }
    }
    
    // MARK: - Mouse Events
    
    /// Install tracking area to receive mouseMoved and cursor updates.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.activeInActiveApp, .mouseMoved, .cursorUpdate],
                                       owner: self, userInfo: nil))
    }
    
    override func cursorUpdate(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateCursor(at: convert(event.locationInWindow, from: nil))
    }
    
    /// Switch cursor when hovering over resize handles; otherwise show crosshair for drawing.
    private func updateCursor(at point: NSPoint) {
        if showResizeHandles && resizeEdgeAt(point) != .none {
            switch resizeEdgeAt(point) {
            case .right: NSCursor.resizeLeftRight.set()
            case .bottom: NSCursor.resizeUpDown.set()
            case .corner: NSCursor.crosshair.set()
            default: break
            }
        } else {
            NSCursor.crosshair.set()
        }
    }
    
    /// Hit-tests which resize edge/handle is under the cursor.
    private func resizeEdgeAt(_ point: NSPoint) -> ResizeEdge {
        guard showResizeHandles else { return .none }
        
        if NSRect(x: canvasSize.width - 12, y: -6, width: 18, height: 18).contains(point) { return .corner }
        if NSRect(x: canvasSize.width - 4, y: 12, width: 12, height: canvasSize.height - 24).contains(point) { return .right }
        if NSRect(x: 12, y: -6, width: canvasSize.width - 24, height: 12).contains(point) { return .bottom }
        return .none
    }
    
    /// Begin drawing, selecting, or resizing based on tool and click location.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        
        // Check for resize handle drags first.
        if showResizeHandles {
            resizeEdge = resizeEdgeAt(point)
            if resizeEdge != .none {
                isResizing = true
                resizeStartSize = canvasSize
                return
            }
        }
        
        let p = clamp(point)
        
        switch currentTool {
        case .pencil, .brush, .eraser:
            currentPath = [p]
            lastPoint = p
            
        case .airbrush:
            airbrushLocation = p
            isAirbrushActive = true
            startAirbrush()
            
        case .fill:
            floodFill(at: p)
            
        case .colorPicker:
            pickColor(at: p)
            
        case .magnifier:
            handleMagnifier(at: p, zoomIn: !event.modifierFlags.contains(.option))
            
        case .text:
            handleTextTool(at: p)
            
        case .line, .rectangle, .ellipse, .roundedRectangle:
            shapeStartPoint = p
            shapeEndPoint = p
            
        case .curve:
            handleCurveMouseDown(at: p)
            
        case .polygon:
            if polygonPoints.isEmpty {
                polygonPoints = [p]
            }
            shapeEndPoint = p
            
        case .freeFormSelect:
            // If we already have a captured selection, hit-test path for moving
            if let path = selectionPath, path.contains(p) {
                startMovingSelection(at: p)
            } else if let rect = selectionRect, selectionPath == nil, rect.contains(p) {
                // Rectangle selection active (from rectangleSelect tool) but current tool is free form
                startMovingSelection(at: p)
            } else {
                // Start a new freehand path
                commitSelection()
                freeFormPath = [p]
                selectionPath = nil
                selectionRect = nil
                selectionImage = nil
                isMovingSelection = false
            }
            
        case .rectangleSelect:
            if let rect = selectionRect, rect.contains(p) {
                startMovingSelection(at: p)
            } else {
                commitSelection()
                shapeStartPoint = p
                shapeEndPoint = p
                selectionPath = nil
            }
        }
        
        setNeedsDisplay(bounds)
    }
    
    /// Update in-progress drawing/selection/shape as the mouse drags.
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        if isResizing {
            handleResizeDrag(to: point)
            return
        }
        
        let p = clamp(point)
        
        switch currentTool {
        case .pencil, .brush, .eraser:
            // Interpolate intermediate points for smoother strokes.
            if let last = lastPoint {
                let distance = hypot(p.x - last.x, p.y - last.y)
                let steps = max(1, Int(distance / 2))
                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let interp = NSPoint(x: last.x + (p.x - last.x) * t, y: last.y + (p.y - last.y) * t)
                    currentPath.append(interp)
                }
            }
            lastPoint = p
            setNeedsDisplay(bounds)
            
        case .airbrush:
            airbrushLocation = p
            
        case .line, .rectangle, .ellipse, .roundedRectangle:
            // Constrain with Shift to perfect square/circle/45-degree line.
            shapeEndPoint = event.modifierFlags.contains(.shift) ? constrainedPoint(from: shapeStartPoint!, to: p) : p
            setNeedsDisplay(bounds)
            
        case .curve:
            shapeEndPoint = p
            setNeedsDisplay(bounds)
            
        case .polygon:
            shapeEndPoint = p
            setNeedsDisplay(bounds)
            
        case .freeFormSelect:
            if isMovingSelection {
                moveSelection(to: p)
            } else {
                freeFormPath.append(p)
            }
            setNeedsDisplay(bounds)
            
        case .rectangleSelect:
            if isMovingSelection {
                moveSelection(to: p)
            } else {
                shapeEndPoint = p
                selectionRect = rectFromPoints(shapeStartPoint!, p)
            }
            setNeedsDisplay(bounds)
            
        default:
            setNeedsDisplay(bounds)
        }
    }
    
    /// Finalize the operation for the current tool on mouse up.
    override func mouseUp(with event: NSEvent) {
        if isResizing {
            isResizing = false
            resizeEdge = .none
            return
        }
        
        let p = clamp(convert(event.locationInWindow, from: nil))
        
        switch currentTool {
        case .pencil, .brush, .eraser:
            commitStroke()
            currentPath = []
            lastPoint = nil
            
        case .airbrush:
            stopAirbrush()
            
        case .line:
            commitLine()
            
        case .rectangle, .ellipse, .roundedRectangle:
            commitShape()
            
        case .curve:
            handleCurveMouseUp(at: p)
            
        case .polygon:
            if event.clickCount >= 2 {
                commitPolygon()
            } else {
                polygonPoints.append(p)
            }
            
        case .freeFormSelect:
            if isMovingSelection {
                isMovingSelection = false
            } else if freeFormPath.count > 2 {
                finalizeFreeFormSelection()
            }
            
        case .rectangleSelect:
            if isMovingSelection {
                isMovingSelection = false
            } else if let start = shapeStartPoint {
                selectionRect = rectFromPoints(start, p)
                captureSelection()
                shapeStartPoint = nil
                shapeEndPoint = nil
            }
            
        default: break
        }
        
        setNeedsDisplay(bounds)
    }
    
    // MARK: - Tool Implementations
    
    /// Tool-specific effective stroke size.
    private func getDrawSize() -> CGFloat {
        switch currentTool {
        case .brush: return brushSize * 2.5
        case .eraser: return brushSize * 3
        default: return brushSize
        }
    }
    
    /// Commits the current stroke to the canvas image (with undo support).
    private func commitStroke() {
        guard currentPath.count > 0, let image = canvasImage else { return }
        
        let drawColor = currentTool == .eraser ? NSColor.white : currentColor
        let drawSize = getDrawSize()
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        drawColor.setStroke()
        drawColor.setFill()
        
        if currentPath.count == 1 {
            let pt = currentPath[0]
            NSBezierPath(ovalIn: NSRect(x: pt.x - drawSize/2, y: pt.y - drawSize/2,
                                        width: drawSize, height: drawSize)).fill()
        } else {
            let path = NSBezierPath()
            path.lineWidth = drawSize
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: currentPath[0])
            for i in 1..<currentPath.count { path.line(to: currentPath[i]) }
            path.stroke()
        }
        
        newImage.unlockFocus()
        canvasImage = newImage
        saveToDocument(actionName: currentTool == .eraser ? "Erase" : "Draw")
    }
    
    // MARK: - Airbrush
    
    /// Starts a timer to periodically spray dots around the airbrush location.
    private func startAirbrush() {
        airbrushTimer?.invalidate()
        airbrushTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            self?.sprayAirbrush()
        }
        sprayAirbrush()
    }
    
    /// Applies one "spray" by drawing random dots within a radius around the current location.
    private func sprayAirbrush() {
        guard isAirbrushActive, let image = canvasImage else { return }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        currentColor.setFill()
        
        let radius = brushSize * 2
        let density = Int(brushSize * 3)
        
        for _ in 0..<density {
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = sqrt(CGFloat.random(in: 0...1)) * radius
            let x = airbrushLocation.x + cos(angle) * dist
            let y = airbrushLocation.y + sin(angle) * dist
            
            if x >= 0 && x <= canvasSize.width && y >= 0 && y <= canvasSize.height {
                let dotSize: CGFloat = 1.0
                NSBezierPath(ovalIn: NSRect(x: x - dotSize/2, y: y - dotSize/2,
                                            width: dotSize, height: dotSize)).fill()
            }
        }
        
        newImage.unlockFocus()
        canvasImage = newImage
        setNeedsDisplay(bounds)
    }
    
    /// Stops the airbrush timer and saves the current sprayed state to the document.
    private func stopAirbrush() {
        isAirbrushActive = false
        airbrushTimer?.invalidate()
        airbrushTimer = nil
        saveToDocument(actionName: "Airbrush")
    }
    
    // MARK: - Shape Tools
    
    /// Commits a line shape to the canvas image.
    private func commitLine() {
        guard let start = shapeStartPoint, let end = shapeEndPoint, let image = canvasImage else {
            resetShapeState()
            return
        }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        currentColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = ToolPaletteState.shared.lineWidth
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
        
        newImage.unlockFocus()
        canvasImage = newImage
        resetShapeState()
        saveToDocument(actionName: "Line")
    }
    
    /// Commits a rectangle/ellipse/rounded-rect shape to the canvas image with the current style.
    private func commitShape() {
        guard let start = shapeStartPoint, let end = shapeEndPoint, let image = canvasImage else {
            resetShapeState()
            return
        }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        let rect = rectFromPoints(start, end)
        let lineWidth = ToolPaletteState.shared.lineWidth
        
        var path: NSBezierPath
        switch currentTool {
        case .rectangle: path = NSBezierPath(rect: rect)
        case .ellipse: path = NSBezierPath(ovalIn: rect)
        case .roundedRectangle:
            let r = min(rect.width, rect.height) * 0.25
            path = NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r)
        default: path = NSBezierPath()
        }
        
        path.lineWidth = lineWidth
        let style = ToolPaletteState.shared.shapeStyle
        
        switch style {
        case .outline:
            currentColor.setStroke()
            path.stroke()
        case .filledWithOutline:
            NSColor(ToolPaletteState.shared.backgroundColor).setFill()
            path.fill()
            currentColor.setStroke()
            path.stroke()
        case .filledNoOutline:
            currentColor.setFill()
            path.fill()
        }
        
        newImage.unlockFocus()
        canvasImage = newImage
        resetShapeState()
        saveToDocument(actionName: "Shape")
    }
    
    // MARK: - Curve Tool
    
    /// First click: establish base line for curve.
    private func handleCurveMouseDown(at point: NSPoint) {
        if curvePhase == 0 {
            shapeStartPoint = point
            shapeEndPoint = point
        }
    }
    
    /// Subsequent clicks: set control points and commit on final phase.
    private func handleCurveMouseUp(at point: NSPoint) {
        if curvePhase == 0 {
            curveBaseStart = shapeStartPoint
            curveBaseEnd = shapeEndPoint
            curvePhase = 1
        } else if curvePhase == 1 {
            curveControlPoint1 = point
            curvePhase = 2
        } else if curvePhase == 2 {
            commitCurve(controlPoint2: point)
        }
    }
    
    /// Draws the final curve using two control points and commits to the canvas.
    private func commitCurve(controlPoint2: NSPoint) {
        guard let start = curveBaseStart, let end = curveBaseEnd, let image = canvasImage else {
            resetCurveState()
            return
        }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        currentColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = ToolPaletteState.shared.lineWidth
        path.move(to: start)
        path.curve(to: end, controlPoint1: curveControlPoint1 ?? start, controlPoint2: controlPoint2)
        path.stroke()
        
        newImage.unlockFocus()
        canvasImage = newImage
        resetCurveState()
        saveToDocument(actionName: "Curve")
    }
    
    /// Resets curve state machine.
    private func resetCurveState() {
        curvePhase = 0
        curveBaseStart = nil
        curveBaseEnd = nil
        curveControlPoint1 = nil
        shapeStartPoint = nil
        shapeEndPoint = nil
    }
    
    // MARK: - Polygon Tool
    
    /// Closes and commits the polygon using the current style.
    private func commitPolygon() {
        guard polygonPoints.count >= 2, let image = canvasImage else {
            polygonPoints = []
            return
        }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        let path = NSBezierPath()
        path.lineWidth = ToolPaletteState.shared.lineWidth
        path.move(to: polygonPoints[0])
        for i in 1..<polygonPoints.count { path.line(to: polygonPoints[i]) }
        path.close()
        
        let style = ToolPaletteState.shared.shapeStyle
        switch style {
        case .outline:
            currentColor.setStroke()
            path.stroke()
        case .filledWithOutline:
            NSColor(ToolPaletteState.shared.backgroundColor).setFill()
            path.fill()
            currentColor.setStroke()
            path.stroke()
        case .filledNoOutline:
            currentColor.setFill()
            path.fill()
        }
        
        newImage.unlockFocus()
        canvasImage = newImage
        polygonPoints = []
        shapeEndPoint = nil
        saveToDocument(actionName: "Polygon")
    }
    
    // MARK: - Selection Tools
    
    /// Begin moving a captured selection; if this is the first move, clear the original area.
    private func startMovingSelection(at point: NSPoint) {
        guard let rect = selectionRect else { return }
        isMovingSelection = true
        selectionOffset = NSPoint(x: point.x - rect.origin.x, y: point.y - rect.origin.y)
        lastSelectionOrigin = rect.origin
        
        // On first move, clear original area. For free-form, clear only masked area.
        if selectionImage != nil && originalSelectionRect == nil {
            originalSelectionRect = rect
            if let path = selectionPath {
                clearPath(path)
            } else {
                clearRect(rect)
            }
        }
    }
    
    /// Update the selection rect while dragging (and translate path if present).
    private func moveSelection(to point: NSPoint) {
        guard var rect = selectionRect else { return }
        let newOrigin = NSPoint(x: point.x - selectionOffset.x, y: point.y - selectionOffset.y)
        if let oldOrigin = lastSelectionOrigin, let path = selectionPath {
            let dx = newOrigin.x - oldOrigin.x
            let dy = newOrigin.y - oldOrigin.y
            let transform = AffineTransform(translationByX: dx, byY: dy)
            path.transform(using: transform)
            lastSelectionOrigin = newOrigin
        }
        rect.origin = newOrigin
        selectionRect = rect
    }
    
    /// Converts a free-form outline into a true masked selection and captures its contents.
    private func finalizeFreeFormSelection() {
        guard freeFormPath.count > 2 else {
            freeFormPath = []
            return
        }
        
        // Build a closed bezier path from points
        let path = NSBezierPath()
        path.move(to: freeFormPath[0])
        for i in 1..<freeFormPath.count { path.line(to: freeFormPath[i]) }
        path.close()
        selectionPath = path
        
        // Compute tight bounds
        let bounds = path.bounds
        selectionRect = bounds
        captureSelection(using: path)
        freeFormPath = []
        lastSelectionOrigin = bounds.origin
    }
    
    /// Captures the current selection rect from the canvas image into selectionImage.
    private func captureSelection() {
        // Rectangle selection capture (legacy)
        guard let rect = selectionRect, rect.width > 0, rect.height > 0, let image = canvasImage else { return }
        
        let captured = NSImage(size: rect.size)
        captured.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: rect.size), from: rect, operation: .copy, fraction: 1.0)
        captured.unlockFocus()
        
        selectionImage = captured
        selectionPath = nil
        lastSelectionOrigin = rect.origin
    }
    
    /// Captures selection using a free-form mask (alpha outside the path).
    private func captureSelection(using path: NSBezierPath) {
        guard let image = canvasImage else { return }
        let bounds = path.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        // Create an offscreen bitmap with alpha
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(bounds.width)),
            pixelsHigh: Int(ceil(bounds.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = bounds.size
        
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            
            // Clear to transparent
            NSColor.clear.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: bounds.size)).fill()
            
            // Clip to translated path and draw image from canvas region
            let translated = path.copy() as! NSBezierPath
            let t = AffineTransform(translationByX: -bounds.origin.x, byY: -bounds.origin.y)
            translated.transform(using: t)
            translated.addClip()
            
            image.draw(in: NSRect(origin: .zero, size: bounds.size),
                       from: bounds,
                       operation: .sourceOver,
                       fraction: 1.0)
        }
        NSGraphicsContext.restoreGraphicsState()
        
        let captured = NSImage(size: bounds.size)
        captured.addRepresentation(rep)
        selectionImage = captured
        selectionRect = bounds
        lastSelectionOrigin = bounds.origin
    }
    
    /// Commits the selection image back into the canvas at its current rect.
    private func commitSelection() {
        guard let rect = selectionRect, let selImage = selectionImage, let image = canvasImage else {
            selectionRect = nil
            selectionImage = nil
            originalSelectionRect = nil
            selectionPath = nil
            lastSelectionOrigin = nil
            return
        }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        selImage.draw(in: rect, from: NSRect(origin: .zero, size: rect.size), operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        
        canvasImage = newImage
        selectionRect = nil
        selectionImage = nil
        originalSelectionRect = nil
        selectionPath = nil
        lastSelectionOrigin = nil
        saveToDocument(actionName: "Move Selection")
    }
    
    /// Clears a rectangular area to white (used when cutting/moving selection).
    private func clearRect(_ rect: NSRect) {
        guard let image = canvasImage else { return }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        NSColor.white.setFill()
        rect.fill()
        newImage.unlockFocus()
        
        canvasImage = newImage
    }
    
    /// Clears a free-form path area to white (used when cutting/moving selection).
    private func clearPath(_ path: NSBezierPath) {
        guard let image = canvasImage else { return }
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        newImage.unlockFocus()
        canvasImage = newImage
    }
    
    // MARK: - Color Picker & Fill
    
    /// Reads the pixel color at the given point and updates the foreground color.
    private func pickColor(at point: NSPoint) {
        guard let image = canvasImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        // Map view point (in points) to bitmap pixel coordinates (account for Retina/backing scale)
        let scaleX = CGFloat(bitmap.pixelsWide) / image.size.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / image.size.height
        
        let px = Int((point.x * scaleX).rounded(.down))
        let py = Int(((canvasSize.height - point.y) * scaleY).rounded(.down))
        
        guard px >= 0, px < bitmap.pixelsWide, py >= 0, py < bitmap.pixelsHigh,
              let color = bitmap.colorAt(x: px, y: py) else { return }
        
        delegate?.colorPicked(color)
        
        // Switch back to the tool we had before entering the picker
        if let previous = previousToolBeforePicker {
            previousToolBeforePicker = nil
            DispatchQueue.main.async {
                ToolPaletteState.shared.currentTool = previous
            }
        }
    }
    
    /// Classic flood fill algorithm (stack-based) with a simple color tolerance,
    /// starting at the clicked pixel.
    private func floodFill(at point: NSPoint) {
        guard let image = canvasImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        // Map start point to pixel space
        let scaleX = CGFloat(bitmap.pixelsWide) / image.size.width
        let scaleY = CGFloat(bitmap.pixelsHigh) / image.size.height
        
        let startX = Int((point.x * scaleX).rounded(.down))
        let startY = Int(((canvasSize.height - point.y) * scaleY).rounded(.down))
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        guard startX >= 0 && startX < width && startY >= 0 && startY < height else { return }
        guard let targetColor = bitmap.colorAt(x: startX, y: startY) else { return }
        
        if colorsMatch(targetColor, currentColor) { return }
        
        var visited = [Bool](repeating: false, count: width * height)
        var stack: [(Int, Int)] = [(startX, startY)]
        
        while !stack.isEmpty {
            let (x, y) = stack.removeLast()
            if x < 0 || x >= width || y < 0 || y >= height { continue }
            let idx = y * width + x
            if visited[idx] { continue }
            
            guard let pixelColor = bitmap.colorAt(x: x, y: y),
                  colorsMatch(pixelColor, targetColor) else { continue }
            
            visited[idx] = true
            bitmap.setColor(currentColor, atX: x, y: y)
            
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))
        }
        
        // Ensure the image rep reports the canvas size in points (keeps mapping consistent)
        bitmap.size = canvasSize
        
        let newImage = NSImage(size: canvasSize)
        newImage.addRepresentation(bitmap)
        canvasImage = newImage
        saveToDocument(actionName: "Fill")
        setNeedsDisplay(bounds)
    }
    
    /// Compares two NSColor values with a tolerance in deviceRGB space.
    private func colorsMatch(_ c1: NSColor, _ c2: NSColor) -> Bool {
        guard let rgb1 = c1.usingColorSpace(.deviceRGB),
              let rgb2 = c2.usingColorSpace(.deviceRGB) else { return false }
        let tolerance: CGFloat = 0.1
        return abs(rgb1.redComponent - rgb2.redComponent) < tolerance &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < tolerance &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < tolerance
    }
    
    // MARK: - Magnifier
    
    /// Zooms in or out by doubling/halving the zoom level via shared state.
    private func handleMagnifier(at point: NSPoint, zoomIn: Bool) {
        let state = ToolPaletteState.shared
        if zoomIn {
            state.zoomLevel = min(8, state.zoomLevel * 2)
        } else {
            state.zoomLevel = max(1, state.zoomLevel / 2)
        }
    }
    
    // MARK: - Text Tool
    
    /// Places an NSTextField at the click point for inline text entry.
    private func handleTextTool(at point: NSPoint) {
        if let tf = textField {
            commitText()
            tf.removeFromSuperview()
            textField = nil
        }
        
        textInsertPoint = point
        
        let tf = NSTextField(frame: NSRect(x: point.x, y: point.y - 20, width: 200, height: 24))
        tf.isBordered = true
        tf.backgroundColor = .white
        tf.font = NSFont(name: ToolPaletteState.shared.fontName, size: ToolPaletteState.shared.fontSize)
        tf.textColor = currentColor
        tf.target = self
        tf.action = #selector(textFieldEntered(_:))
        addSubview(tf)
        tf.becomeFirstResponder()
        textField = tf
    }
    
    /// Called when the user presses Return in the text field; commits text to image.
    @objc private func textFieldEntered(_ sender: NSTextField) {
        commitText()
        sender.removeFromSuperview()
        textField = nil
    }
    
    /// Renders the text field's contents into the canvas image at the insertion point.
    private func commitText() {
        guard let tf = textField, let point = textInsertPoint, let image = canvasImage else { return }
        
        let text = tf.stringValue
        guard !text.isEmpty else { return }
        
        let newImage = NSImage(size: canvasSize)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: canvasSize))
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: tf.font ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: currentColor
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        attrString.draw(at: point)
        
        newImage.unlockFocus()
        canvasImage = newImage
        textInsertPoint = nil
        saveToDocument(actionName: "Text")
    }
    
    // MARK: - Resize Handling
    
    /// Responds to dragging on resize handles by requesting a new canvas size.
    private func handleResizeDrag(to point: NSPoint) {
        var newSize = canvasSize
        
        switch resizeEdge {
        case .right:
            newSize.width = max(50, point.x)
        case .bottom:
            // Bottom handle: dragging down increases height
            newSize.height = max(50, resizeStartSize.height + (resizeStartSize.height - point.y))
        case .corner:
            newSize.width = max(50, point.x)
            newSize.height = max(50, resizeStartSize.height + (resizeStartSize.height - point.y))
        case .none:
            return
        }
        
        // Request resize through ContentView (which handles the actual resize)
        delegate?.requestCanvasResize(newSize)
    }
    
    // MARK: - Helpers
    
    /// Clamp a point to the canvas bounds.
    private func clamp(_ point: NSPoint) -> NSPoint {
        NSPoint(x: max(0, min(point.x, canvasSize.width)), y: max(0, min(point.y, canvasSize.height)))
    }
    
    /// Construct a rect from two corner points.
    private func rectFromPoints(_ p1: NSPoint, _ p2: NSPoint) -> NSRect {
        NSRect(x: min(p1.x, p2.x), y: min(p1.y, p2.y),
               width: abs(p2.x - p1.x), height: abs(p2.y - p1.y))
    }
    
    /// Constrain to square/circle or 45-degree line when holding Shift.
    private func constrainedPoint(from start: NSPoint, to end: NSPoint) -> NSPoint {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        let d = max(dx, dy)
        return NSPoint(x: start.x + d * (end.x > start.x ? 1 : -1),
                       y: start.y + d * (end.y > start.y ? 1 : -1))
    }
    
    /// Clears shape preview state.
    private func resetShapeState() {
        shapeStartPoint = nil
        shapeEndPoint = nil
    }
    
    /// Serializes the current canvas image as PNG and saves to the document,
    /// optionally registering an undo action with a descriptive name.
    private func saveToDocument(actionName: String?) {
        guard let image = canvasImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        
        documentDataHash = pngData.hashValue
        
        if let name = actionName {
            delegate?.saveWithUndo(newData: pngData, image: image, actionName: name)
        } else {
            delegate?.saveToDocument(pngData, image: image)
        }
    }
}

// MARK: - Color Extension

/// Convenience color comparison with tolerance in deviceRGB space.
extension NSColor {
    func isClose(to other: NSColor?, tolerance: CGFloat = 0.1) -> Bool {
        guard let other = other,
              let c1 = self.usingColorSpace(.deviceRGB),
              let c2 = other.usingColorSpace(.deviceRGB) else { return false }
        
        return abs(c1.redComponent - c2.redComponent) < tolerance &&
               abs(c1.greenComponent - c2.greenComponent) < tolerance &&
               abs(c1.blueComponent - c2.blueComponent) < tolerance
    }
}

