//
//  ToastModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-08.
//

import Foundation
import SwiftUI

struct ToastModifier: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .toast(isPresenting: $toastManager.show) {
                toastManager.toast
            }
    }
}

extension View {
    func toaster() -> some View {
        modifier(ToastModifier())
    }
}
