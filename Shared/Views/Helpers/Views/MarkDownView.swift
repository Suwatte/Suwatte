//
//  MarkdownView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import SwiftUI

struct MarkDownView: View {
    let text: String
    var font: Font.Weight = .light
    @State private var formattedText: AttributedString?

    var body: some View {
        Group {
            if let formattedText = formattedText {
                Text(formattedText)
                    .fontWeight(font)
            } else {
                Text(text)
                    .fontWeight(font)
            }
        }
        .onAppear(perform: formatText)
    }

    private func formatText() {
        try? formattedText = AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    }
}
