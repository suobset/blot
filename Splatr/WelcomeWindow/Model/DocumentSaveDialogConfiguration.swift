//
//  DocumentSaveDialogConfiguration.swift
//  CodeEditWelcomeWindow
//
//  Created by Giorgi Tchelidze on 25.05.25.
//

import SwiftUI
import UniformTypeIdentifiers

/// A configuration struct for presenting a save document dialog.
public struct DocumentSaveDialogConfiguration {

    /// The prompt displayed on the save dialog (e.g., the action button title).
    public var prompt: String

    /// The label for the name input field.
    public var nameFieldLabel: String

    /// The default name of the file or folder being saved.
    public var defaultFileName: String

    /// The list of allowed content types presented in the save dialog.
    ///
    /// Used to constrain user input (e.g., extensions or format dropdown).
    public var allowedContentTypes: [UTType]

    /// The default file type identifier used when creating the document programmatically.
    ///
    /// This is passed directly to `NSDocument.makeUntitledDocument(ofType:)`
    /// and should match one of the `allowedContentTypes` if possible.
    public var defaultFileType: UTType

    /// The title of the save dialog window.
    public var title: String

    /// The initial directory shown when the dialog appears.
    public var directoryURL: URL?

    /// Creates a new `DocumentSaveDialogConfiguration` with the given parameters.
    ///
    /// - Parameters:
    ///   - prompt: The prompt shown in the dialog. Default is `"Create Document"`.
    ///   - nameFieldLabel: The label for the name field. Default is `"File Name:"`.
    ///   - defaultFileName: The default file or folder name. Default is `"Untitled"`.
    ///   - allowedContentTypes: The allowed content types for the save dialog. Default is `[.plainText]`.
    ///   - defaultFileType: The content type that will be used to create the document. Defaults to `.plainText`.
    ///   - title: The title of the save dialog window. Default is `"Create a New Document"`.
    ///   - directoryURL: The default directory URL. Default is the user’s Documents folder.
    public init(
        prompt: String = "Create Document",
        nameFieldLabel: String = "File Name:",
        defaultFileName: String = "Untitled",
        allowedContentTypes: [UTType] = [UTType.plainText],
        defaultFileType: UTType = UTType.plainText,
        title: String = "Create a New Document",
        directoryURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
        includeExtension: Bool = true
    ) {
        self.prompt = prompt
        self.nameFieldLabel = nameFieldLabel
        self.defaultFileName = defaultFileName
        self.allowedContentTypes = allowedContentTypes
        self.defaultFileType = defaultFileType
        self.title = title
        self.directoryURL = directoryURL
    }
}
