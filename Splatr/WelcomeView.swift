//
//  WelcomeWindow.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/6/26.
//

import SwiftUI

// MARK: - Welcome View

/// A custom welcome window UI that lets users create a new canvas, open an existing
/// image/document, or pick from a list of recent documents.
struct WelcomeView: View {
    /// Uses NSDocumentController to read recent documents maintained by the system.
    private var recentDocuments: [URL] {
        NSDocumentController.shared.recentDocumentURLs
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                leftPanel
                    .frame(width: 360)
                
                rightPanel
                    .frame(width: 280)
            }
            
            // Custom close button that terminates the app (since this is a welcome window).
            CloseButton {
                NSApp.terminate(nil)
            }
            .padding(.top, 14)
            .padding(.leading, 14)
        }
        .frame(width: 640, height: 420)
        .background {
            // Glassy background look combining material, color, and gradient.
            ZStack {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.7)
                
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            // Subtle border for a polished look.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
    
    // MARK: - Left Panel
    
    /// Left side contains branding (icon, name, version) and primary actions.
    private var leftPanel: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App icon with a blurred shadow behind for depth.
            ZStack {
                if let iconImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)
                        .opacity(0.5)
                        .offset(y: 20)
                }
                
                if let iconImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 112, height: 112)
                }
            }
            
            Spacer().frame(height: 20)
            
            Text("Splatr")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Version \(Bundle.main.appVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer().frame(height: 44)
            
            // Primary actions.
            VStack(spacing: 8) {
                GlassActionButton(
                    icon: "paintbrush",
                    title: "New Canvas"
                ) {
                    NSDocumentController.shared.newDocument(nil)
                    WelcomeWindowController.shared.close()
                }
                
                GlassActionButton(
                    icon: "folder",
                    title: "Open Existing Canvas/Image"
                ) {
                    WelcomeWindowController.shared.close()
                    // Small delay to allow welcome window to close before open panel.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSDocumentController.shared.openDocument(nil)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Right Panel
    
    /// Right panel lists recent documents and allows opening them directly.
    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)
            
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
                .padding(.horizontal, 12)
            
            if recentDocuments.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(recentDocuments, id: \.self) { url in
                            GlassFileRow(url: url) {
                                NSDocumentController.shared.openDocument(
                                    withContentsOf: url,
                                    display: true
                                ) { _, _, _ in
                                    WelcomeWindowController.shared.close()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background {
            Color.black.opacity(0.15)
        }
    }
    
    /// Shown when there are no recent documents.
    private var emptyState: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.tertiary)
                
                Text("No Recent Documents")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Close Button

/// A custom close button in the top-left that mirrors window controls,
/// used to terminate the app from the welcome window.
struct CloseButton: View {
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 12, height: 12)
                
                if isHovering {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Glass Action Button

/// A glass-styled button used for primary actions on the welcome screen.
struct GlassActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHovering ? .primary : .secondary)
                    .frame(width: 18)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .opacity(isHovering ? 1.0 : 0.85)
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isHovering ? 1 : 0.8)
                    
                    if isHovering {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovering ? 0.4 : 0.25),
                                Color.white.opacity(isHovering ? 0.2 : 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(isHovering ? 0.15 : 0.1), radius: isHovering ? 8 : 4, y: isHovering ? 4 : 2)
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .simultaneousGesture(
            // Simple press animation feedback.
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Glass File Row

/// A recent document row with a preview thumbnail (when available) and path hint.
/// Clicking opens the document and closes the welcome window.
struct GlassFileRow: View {
    let url: URL
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var thumbnail: NSImage?
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Thumbnail or generic file icon.
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                    
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 26, height: 26)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    /// Attempts to load the file as an NSImage and produce a small preview.
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = NSImage(contentsOf: url) {
                let thumb = image.resized(to: NSSize(width: 64, height: 64))
                DispatchQueue.main.async {
                    self.thumbnail = thumb
                }
            }
        }
    }
}

// MARK: - Visual Effect Blur

/// Wrapper to use NSVisualEffectView from SwiftUI for glassy backgrounds.
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Window Controller

/// Manages the lifecycle of the custom welcome window. Keeps a reference to avoid
/// deallocation and configures the window with a transparent titlebar and custom UI.
class WelcomeWindowController {
    static let shared = WelcomeWindowController()
    private(set) var window: NSWindow?
    
    /// Shows (or re-shows) the welcome window and activates the app.
    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .normal
        window.collectionBehavior = [.managed, .participatesInCycle]
        window.center()
        window.contentView = NSHostingView(rootView: WelcomeView())
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = window
    }
    
    /// Closes the welcome window if it exists.
    func close() {
        window?.close()
    }
}

// MARK: - Helpers

extension Bundle {
    /// Returns a user-friendly version string "X.Y.Z (Build)" from Info.plist.
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

extension NSImage {
    /// Draws the image into a new NSImage of the specified size.
    func resized(to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        self.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .frame(width: 640, height: 420)
}

