//
//  Toast+ViewModel.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//

import AlertToast
import Combine
import SwiftUI

final class ToastManager: ObservableObject {
    @Published var show = false
    @Published var toast = AlertToast(type: .regular, title: "Default") {
        didSet {
            withAnimation {
                show = false
            }

            if toast.type != .loading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        self.show = true
                    }
                }
            }
        }
    }

    static var shared = ToastManager()
    func stop() {
        show = false
    }

    func setToast(toast: AlertToast) {
        self.toast = toast
    }

    func setLoading() {
        toast = .init(displayMode: .alert, type: .loading)
    }

    func setError(error: Error) {
        Logger.shared.error("[ToastManager] [DUP] \(error.localizedDescription)")
        toast = AlertToast(type: .error(.red), title: error.localizedDescription)
    }

    func setError(msg: String) {
        toast = .init(displayMode: .alert, type: .error(.red), title: msg)
    }

    func setComplete(title: String? = nil) {
        toast = .init(displayMode: .alert, type: .complete(.green), title: title)
    }
}
