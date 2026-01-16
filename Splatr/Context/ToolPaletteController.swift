//
//  ToolPaletteController.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import AppKit
import SwiftUI
import Combine

/// Manages creation and visibility of floating palettes (tools, colors, navigator,
/// text options, custom colors) as NSPanels. Also coordinates showing/hiding in response
/// to app activation and current tool selection.
class ToolPaletteController {
    static let shared = ToolPaletteController()
    
    private var toolPaletteWindow: NSPanel?
    private var colorPaletteWindow: NSPanel?
    private var navigatorWindow: NSPanel?
    private var textOptionsWindow: NSPanel?
    private var customColorsWindow: NSPanel?
    
    private var toolPaletteVisible = true
    private var colorPaletteVisible = true
    private var navigatorVisible = true
    private var textOptionsVisible = false
    private var customColorsVisible = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Automatically show text options when the Text tool is selected.
        ToolPaletteState.shared.$currentTool
            .sink { [weak self] tool in
                if tool == .text {
                    self?.showTextOptions()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Convenience for creating consistent floating utility panels.
    private func createPanel(title: String, rect: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.level = .floating
        return panel
    }
    
    /// Shows all palettes that make sense for the current tool selection.
    func showAllPalettes() {
        toolPaletteVisible = true
        colorPaletteVisible = true
        navigatorVisible = true
        showToolPalette()
        showColorPalette()
        showNavigator()
        if textOptionsVisible || ToolPaletteState.shared.currentTool == .text {
            showTextOptions()
        }
        if customColorsVisible {
            showCustomColors()
        }
    }
    
    /// Hides all palettes and marks them as not visible.
    func hideAllPalettes() {
        toolPaletteVisible = false
        colorPaletteVisible = false
        navigatorVisible = false
        textOptionsVisible = false
        customColorsVisible = false
        toolPaletteWindow?.orderOut(nil)
        colorPaletteWindow?.orderOut(nil)
        navigatorWindow?.orderOut(nil)
        textOptionsWindow?.orderOut(nil)
        customColorsWindow?.orderOut(nil)
    }
    
    /// Re-shows palettes that were previously visible when the app becomes active.
    func showPalettesIfNeeded() {
        if toolPaletteVisible { toolPaletteWindow?.orderFront(nil) }
        if colorPaletteVisible { colorPaletteWindow?.orderFront(nil) }
        if navigatorVisible { navigatorWindow?.orderFront(nil) }
        if textOptionsVisible { textOptionsWindow?.orderFront(nil) }
        if customColorsVisible { customColorsWindow?.orderFront(nil) }
    }
    
    /// Temporarily hides palettes when the app resigns active.
    func hidePalettesTemporarily() {
        toolPaletteWindow?.orderOut(nil)
        colorPaletteWindow?.orderOut(nil)
        navigatorWindow?.orderOut(nil)
        textOptionsWindow?.orderOut(nil)
        customColorsWindow?.orderOut(nil)
    }
    
    /// Shows the Tools palette as a floating NSPanel.
    func showToolPalette() {
        toolPaletteVisible = true
        if let window = toolPaletteWindow {
            window.orderFront(nil)
            return
        }
        
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let panel = createPanel(title: "Tools", rect: NSRect(x: 50, y: screenHeight - 520, width: 66, height: 440))
        panel.contentView = NSHostingView(rootView: ToolPaletteView())
        panel.orderFront(nil)
        toolPaletteWindow = panel
    }
    
    /// Shows the Colors palette as a floating NSPanel.
    func showColorPalette() {
        colorPaletteVisible = true
        if let window = colorPaletteWindow {
            window.orderFront(nil)
            return
        }
        
        let panel = createPanel(title: "Colors", rect: NSRect(x: 150, y: 80, width: 370, height: 80))
        panel.contentView = NSHostingView(rootView: ColorPaletteView())
        panel.orderFront(nil)
        colorPaletteWindow = panel
    }
    
    /// Shows the Navigator palette (preview image) as a floating NSPanel.
    func showNavigator() {
        navigatorVisible = true
        if let window = navigatorWindow {
            window.orderFront(nil)
            return
        }
        
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let panel = createPanel(title: "Navigator", rect: NSRect(x: screenWidth - 220, y: screenHeight - 250, width: 180, height: 160))
        panel.contentView = NSHostingView(rootView: NavigatorView())
        panel.orderFront(nil)
        navigatorWindow = panel
    }
    
    /// Shows the Text Options palette as a floating NSPanel.
    func showTextOptions() {
        textOptionsVisible = true
        if let window = textOptionsWindow {
            window.orderFront(nil)
            return
        }
        
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let screenHeight = NSScreen.main?.frame.height ?? 800
        let panel = createPanel(title: "Text Options", rect: NSRect(x: screenWidth - 220, y: screenHeight - 430, width: 180, height: 160))
        panel.contentView = NSHostingView(rootView: TextOptionsView())
        panel.delegate = TextOptionsPanelDelegate.shared
        panel.orderFront(nil)
        textOptionsWindow = panel
    }
    
    /// Hides the Text Options palette and marks it as not visible.
    func hideTextOptions() {
        textOptionsVisible = false
        textOptionsWindow?.orderOut(nil)
    }
    
    /// Toggles Text Options palette visibility.
    func toggleTextOptions() {
        if textOptionsVisible {
            hideTextOptions()
        } else {
            showTextOptions()
        }
    }
    
    /// Shows the Custom Colors palette as a floating NSPanel.
    func showCustomColors() {
        customColorsVisible = true
        if let window = customColorsWindow {
            window.orderFront(nil)
            return
        }
        
        let panel = createPanel(title: "Custom Colors", rect: NSRect(x: 150, y: 170, width: 260, height: 130))
        panel.contentView = NSHostingView(rootView: CustomColorsPaletteView())
        panel.delegate = CustomColorsPanelDelegate.shared
        panel.orderFront(nil)
        customColorsWindow = panel
    }
    
    /// Hides the Custom Colors palette and marks it as not visible.
    func hideCustomColors() {
        customColorsVisible = false
        customColorsWindow?.orderOut(nil)
    }
    
    /// Toggles Custom Colors palette visibility.
    func toggleCustomColors() {
        if customColorsVisible {
            hideCustomColors()
        } else {
            showCustomColors()
        }
    }
}

// MARK: - Text Options Panel Delegate

/// Tracks Text Options panel lifecycle to keep controller visibility flags in sync.
class TextOptionsPanelDelegate: NSObject, NSWindowDelegate {
    static let shared = TextOptionsPanelDelegate()
    
    func windowWillClose(_ notification: Notification) {
        ToolPaletteController.shared.hideTextOptions()
    }
}

// MARK: - Custom Colors Panel Delegate

/// Tracks Custom Colors panel lifecycle to keep controller visibility flags in sync.
class CustomColorsPanelDelegate: NSObject, NSWindowDelegate {
    static let shared = CustomColorsPanelDelegate()
    
    func windowWillClose(_ notification: Notification) {
        ToolPaletteController.shared.hideCustomColors()
    }
}
