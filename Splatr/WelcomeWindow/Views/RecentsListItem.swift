//
//  RecentsListItem.swift
//  CodeEditModules/WelcomeModule
//
//  Created by Ziyuan Zhao on 2022/3/18.
//

import SwiftUI

// Old extension used for non-sandboxed URLs
extension String {
    func abbreviatingWithTildeInPath() -> String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}

public struct RecentsListItem: View {
    let projectPath: URL

    public init(projectPath: URL) {
        self.projectPath = projectPath
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: projectPath.path(percentEncoded: false)))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading) {
                Text(projectPath.lastPathComponent)
                    .foregroundColor(.primary)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(formattedPath(for: projectPath))
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .frame(height: 36)
        .contentShape(Rectangle())
    }

    func formattedPath(for url: URL) -> String {
        let fullPath = url.deletingLastPathComponent().path
        if let realHome = realUserHomeDirectory(),
           fullPath.hasPrefix(realHome) {
            return "~" + fullPath.dropFirst(realHome.count)
        } else {
            return fullPath
        }
    }

    func realUserHomeDirectory() -> String? {
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir { // swiftlint:disable:this identifier_name
            return String(cString: home)
        }
        return nil
    }
}
