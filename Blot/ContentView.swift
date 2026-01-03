//
//  ContentView.swift
//  Blot
//
//  Created by Kushagra Srivastava on 1/2/26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: BlotDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(BlotDocument()))
}
