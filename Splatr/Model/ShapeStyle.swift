//
//  ShapeStyle.swift
//  Splatr
//
//  Created by Kushagra Srivastava on 1/16/26.
//

import Foundation

/// Shape rendering modes for shape tools.
enum ShapeStyle: Int, CaseIterable {
    case outline = 0
    case filledWithOutline = 1
    case filledNoOutline = 2
}
