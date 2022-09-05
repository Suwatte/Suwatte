//
//  CloseButton.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-22.
//

import SwiftUI

private struct CloseButton: ViewModifier {
    @Environment(\.presentationMode) var presentationMode
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
    }
}

extension View {
    func closeButton() -> some View {
        modifier(CloseButton())
    }
}
