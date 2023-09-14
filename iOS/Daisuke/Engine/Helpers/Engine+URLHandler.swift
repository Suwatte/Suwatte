//
//  Engine+URLHandler.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import UIKit

extension DSK {
    private func handleGetIdentifier(for url: String) async -> [ContentIdentifier] {
        var results = [ContentIdentifier]()
        let sources = await getActiveSources()
        for source in sources {
            let result = try? await source.getIdentifiers(for: url)
            guard let result else { continue }
            results.append(.init(contentId: result.contentId, sourceId: source.id))
        }
        return results
    }

    @discardableResult
    func handleURL(for url: URL) async -> Bool {
        await MainActor.run {
            ToastManager.shared.loading = true
        }
        let results = await handleGetIdentifier(for: url.relativeString)
        await MainActor.run {
            ToastManager.shared.loading = false
        }
        if results.isEmpty {
            return false
        }
        if results.count == 1 {
            // Only One Result, navigate immediately
            await MainActor.run(body: {
                NavigationModel.shared.identifier = results.first
            })
            return true
        }

        // Show Alert
        let alert = await UIAlertController(title: "Handler", message: "Multiple Sources can handle this url", preferredStyle: .actionSheet)

        // Add Actions
        for result in results {
            guard let source = await getSource(id: result.sourceId) else {
                continue
            }
            // Add Action
            let action = await UIAlertAction(title: source.name, style: .default) { _ in
                NavigationModel.shared.identifier = result
            }
            await alert.addAction(action)
        }

        let cancel = await UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        await alert.addAction(cancel)

        // Present
        await MainActor.run(body: {
            KEY_WINDOW?.rootViewController?.present(alert, animated: true)
        })

        return true
    }
}
