//
//  +ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation

extension DSKAuthView {
    final class ViewModel: ObservableObject {
        var runner: AnyRunner
        @Published var loadable: Loadable<DSKCommon.User?> = .idle

        init(runner: AnyRunner) {
            self.runner = runner
        }

        func load() {
            Task { @MainActor in
                loadable = .loading
                do {
                    let data = try await runner.getAuthenticatedUser()
                    loadable = .loaded(data)
                } catch {
                    loadable = .failed(error)
                }
            }
        }
    }
}
