//
//  CloseButton.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-22.
//

import SwiftUI

private struct CloseButton: ViewModifier {
    @Environment(\.presentationMode) var presentationMode
    var title: String
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(title) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
    }
}

extension View {
    func closeButton(title: String = "Close") -> some View {
        modifier(CloseButton(title: title))
    }
}
