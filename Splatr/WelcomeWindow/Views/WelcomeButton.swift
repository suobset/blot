//
//  WelcomeButton.swift
//  CodeEditModules/WelcomeModule
//
//  Created by Ziyuan Zhao on 2022/3/18.
//

import SwiftUI

public struct WelcomeButton: View {
    var iconName: String
    var title: String
    var action: () -> Void

    @FocusState private var isfocused: Bool

    public init(iconName: String, title: String, action: @escaping () -> Void) {
        self.iconName = iconName
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action, label: {
            HStack(spacing: 7) {
                Image(systemName: iconName)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
        })
        .buttonStyle(WelcomeActionButtonStyle())
        .focused($isfocused)
        .modifier(FocusRingModifier(isFocused: isfocused, shape: buttonShape))
    }

    private var buttonShape: some InsettableShape {
        if #available(macOS 26, *) {
            return .capsule
        } else {
            return .rect(cornerRadius: 8)
        }
    }
}

struct WelcomeActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        @ViewBuilder var buttonBody: some View {
            let base = configuration.label
                .contentShape(Rectangle())
                .padding(7)
                .frame(height: 36)
                .background(Color(.labelColor).opacity(configuration.isPressed ? 0.1 : 0.05))

            if #available(macOS 26, *) {
                base.clipShape(Capsule())
            } else {
                base.clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        return buttonBody
    }
}
