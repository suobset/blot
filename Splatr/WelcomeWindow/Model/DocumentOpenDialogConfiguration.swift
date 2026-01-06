//
//  DocumentOpenDialogConfiguration.swift
//  CodeEditWelcomeWindow
//
//  Created by Giorgi Tchelidze on 25.05.25.
//

import SwiftUI
import UniformTypeIdentifiers

/// A configuration struct for presenting an open document dialog.
public struct DocumentOpenDialogConfiguration {

    /// The title displayed on the open document dialog.
    public var title: String

    /// The content types that can be selected in the open dialog.
    public var allowedContentTypes: [UTType]

    /// A Boolean value indicating whether files can be selected.
    public var canChooseFiles: Bool

    /// A Boolean value indicating whether directories can be selected.
    public var canChooseDirectories: Bool

    /// The initial directory URL shown in the dialog.
    public var directoryURL: URL?

    /// Creates a new `DocumentOpenDialogConfiguration` with the given parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the open dialog. Default is `"Open Document"`.
    ///   - allowedContentTypes: The allowed content types. Default is `[.plainText]`.
    ///   - canChooseFiles: Indicates whether files can be selected. Default is `true`.
    ///   - canChooseDirectories: Indicates whether directories can be selected. Default is `false`.
    ///   - directoryURL: The default URL to display. Default is the user's document directory.
    public init(
        title: String = "Open Document",
        allowedContentTypes: [UTType] = [],
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false,
        directoryURL: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    ) {
        self.title = title
        self.allowedContentTypes = allowedContentTypes
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
        self.directoryURL = directoryURL
    }
}
