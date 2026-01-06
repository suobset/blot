//
//  WelcomeActions.swift
//  WelcomeWindow
//
//  Created by Giorgi Tchelidze on 28.05.25.
//

import SwiftUI

/// A representation of a limited set of welcome action views, supporting up to three actions.
public enum WelcomeActions {

    /// No actions are present.
    case none

    /// A single action view is present.
    /// - Parameter view: The view to be shown as the action.
    case one(AnyView)

    /// Two action views are present.
    /// - Parameters:
    ///   - first: The first view to be shown.
    ///   - second: The second view to be shown.
    case two(AnyView, AnyView)

    /// Three action views are present.
    /// - Parameters:
    ///   - first: The first view to be shown.
    ///   - second: The second view to be shown.
    ///   - third: The third view to be shown.
    case three(AnyView, AnyView, AnyView)

    /// The number of views contained in the current case.
    public var count: Int {
        switch self {
        case .none: return 0
        case .one: return 1
        case .two: return 2
        case .three: return 3
        }
    }
}
