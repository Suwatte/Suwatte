//
//  DSK+EventHandlers.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation
import UIKit

extension DaisukeEngine {
    func handleGetIdentifier(for url: String) async -> [ContentIdentifier] {
        let sources = getSources()
        var results = [ContentIdentifier]()
        for source in sources {
            do {
                let result = try await source.getIdentifiers(for: url)
                if let result = result {
                    results.append(.init(contentId: result.contentId, sourceId: source.id))
                }
            } catch {
                Logger.shared.error("\(error.localizedDescription)")
            }
        }
        return results
    }

    @discardableResult
    func handleURL(for url: URL) async -> Bool {
        let results = await SourceManager.shared.handleGetIdentifier(for: url.relativeString)

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
        let alert = await UIAlertController(title: "Handler", message: "Multiple Content Sources can handle this url", preferredStyle: .actionSheet)

        // Add Actions
        for result in results {
            guard let source = SourceManager.shared.getSource(id: result.sourceId) else {
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
