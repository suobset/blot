//
//  ActionsBuilder.swift
//  WelcomeWindow
//
//  Created by Giorgi Tchelidze on 28.05.25.
//

import SwiftUI

/// A result builder used to construct `WelcomeActions` from SwiftUI views.
@resultBuilder
public enum ActionsBuilder {

    /// Builds an empty set of welcome actions.
    /// - Returns: A `WelcomeActions.none` value.
    public static func buildBlock() -> WelcomeActions {
        .none
    }

    /// Builds a single welcome action view.
    /// - Parameter view1: The first view to include in the actions.
    /// - Returns: A `WelcomeActions.one` containing the provided view.
    public static func buildBlock<V1: View>(_ view1: V1) -> WelcomeActions {
        .one(AnyView(view1))
    }

    /// Builds two welcome action views.
    /// - Parameters:
    ///   - view1: The first view to include.
    ///   - view2: The second view to include.
    /// - Returns: A `WelcomeActions.two` with the provided views.
    public static func buildBlock<V1: View, V2: View>(_ view1: V1, _ view2: V2) -> WelcomeActions {
        .two(AnyView(view1), AnyView(view2))
    }

    /// Builds three welcome action views.
    /// - Parameters:
    ///   - view1: The first view to include.
    ///   - view2: The second view to include.
    ///   - view3: The third view to include.
    /// - Returns: A `WelcomeActions.three` with the provided views.
    public static func buildBlock<V1: View, V2: View, V3: View>(
        _ view1: V1, _ view2: V2, _ view3: V3
    ) -> WelcomeActions {
        .three(AnyView(view1), AnyView(view2), AnyView(view3))
    }
}
