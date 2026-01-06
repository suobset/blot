//
//  URL+isDirectory.swift
//  WelcomeWindow
//
//  Created by Giorgi Tchelidze on 08.06.25.
//

import SwiftUI

extension URL {
    /// True when the URL represents a directory (folders and file‐packages).
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
