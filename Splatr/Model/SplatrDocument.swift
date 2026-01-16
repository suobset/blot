//
//  splatrDocument.swift
//  splatr
//
//  Created by Kushagra Srivastava on 1/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

// Custom .splatr format
extension UTType {
    /// The Uniform Type Identifier for the app's custom document format.
    /// Declared as exported type "com.splatr.drawing" in the app’s Info.plist.
    static var splatr: UTType {
        UTType(exportedAs: "com.splatr.drawing")
    }
}

/// The `splatrDocument` file format stores each canvas as a simple `.splatr` file.
/// The file layout is:
/// - First 8 bytes: width as Float64
/// - Next 8 bytes: height as Float64
/// - Remaining bytes: PNG data for the canvas image
///
/// This type also supports opening common image formats (PNG, JPEG, BMP, TIFF),
/// and saving as PNG, JPEG, PDF, or `.splatr`.
struct splatrDocument: FileDocument {
    /// PNG data representing the canvas image.
    var canvasData: Data
    /// Canvas size in pixels.
    var canvasSize: CGSize
    
    /// Default size used for new blank documents before fitting to window.
    static let defaultSize = CGSize(width: 800, height: 600)
    
    /// Create a new blank document with the specified size.
    init(size: CGSize = splatrDocument.defaultSize) {
        self.canvasSize = size
        self.canvasData = splatrDocument.createBlankCanvas(size: size)
    }
    
    // Read PNG, JPEG, BMP, TIFF, and our custom .splatr
    static var readableContentTypes: [UTType] { [.splatr, .png, .jpeg, .bmp, .tiff] }
    
    // Save as .splatr by default
    static var writableContentTypes: [UTType] { [.splatr, .png, .jpeg, .pdf] }
    
    /// Initializes the document from a file on disk. Supports `.splatr` (custom header + PNG)
    /// as well as standard bitmap image formats (converted to PNG internally).
    init(configuration: ReadConfiguration) throws {
        let contentType = configuration.contentType
        
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        if contentType == .splatr {
            // .splatr is a simple format: 8 bytes for width/height as Float64, then PNG data
            // We need to ensure that at least the header data exists here
            guard data.count > 16 else { throw CocoaError(.fileReadCorruptFile) }
            
            let width = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float64.self) }
            let height = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Float64.self) }
            let imageData = data.dropFirst(16)
            
            self.canvasSize = CGSize(width: width, height: height)
            self.canvasData = Data(imageData)
        } else {
            // Regular image format
            guard let nsImage = NSImage(data: data),
                  let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData)
            else {
                throw CocoaError(.fileReadCorruptFile)
            }
            
            self.canvasSize = CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
            
            // Normalize to PNG for internal storage.
            if let pngData = bitmap.representation(using: .png, properties: [:]) {
                self.canvasData = pngData
            } else {
                self.canvasData = data
            }
        }
    }
    
    /// Writes the document to disk using a `FileWrapper`, selecting format based on the
    /// requested content type (splatr, jpeg, pdf, png).
    ///
    /// - Returns: A FileWrapper containing the encoded file contents.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let contentType = configuration.contentType
        
        guard let image = NSImage(data: canvasData),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        let outputData: Data
        
        switch contentType {
        case .splatr:
            // Custom format: size header + PNG data
            var header = Data()
            var width = Float64(canvasSize.width)
            var height = Float64(canvasSize.height)
            header.append(Data(bytes: &width, count: 8))
            header.append(Data(bytes: &height, count: 8))
            
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            outputData = header + pngData
            
        case .jpeg:
            guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            outputData = jpegData
            
        case .pdf:
            // Render the canvas image into a single-page PDF with the same size.
            let pdfData = NSMutableData()
            let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
            var rect = CGRect(origin: .zero, size: canvasSize)
            let context = CGContext(consumer: consumer, mediaBox: &rect, nil)!
            context.beginPDFPage(nil)
            if let cgImage = bitmap.cgImage {
                context.draw(cgImage, in: rect)
            }
            context.endPDFPage()
            context.closePDF()
            outputData = pdfData as Data
            
        default: // PNG
            guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            outputData = pngData
        }
        
        return FileWrapper(regularFileWithContents: outputData)
    }
    
    /// Creates a blank white PNG image of the given size and returns its data.
    static func createBlankCanvas(size: CGSize) -> Data {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            return Data()
        }
        return pngData
    }
}

