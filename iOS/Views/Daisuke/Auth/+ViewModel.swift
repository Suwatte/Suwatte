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

        func load() async throws -> DSKCommon.User? {
            try await runner.getAuthenticatedUser()
        }
        
        func reload() {
            loadable = .idle
        }
    }
}
