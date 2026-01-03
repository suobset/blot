//
//  BlotApp.swift
//  Blot
//
//  Created by Kushagra Srivastava on 1/2/26.
//

import SwiftUI

@main
struct BlotApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: BlotDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
