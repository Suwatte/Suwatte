//
//  Engine+URLHandler.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation
import UIKit

extension DSK {
    private func handleDeepLink(for url: String) async -> [(DSKCommon.DeepLinkContext, String)] {
        var results = [(DSKCommon.DeepLinkContext, String)]()
        let sources = await getActiveSources()
        let trackers = await getActiveTrackers()

        for source in sources {
            guard source.intents.canHandleURL ?? false else { continue }
            guard let owningLinks = source.config?.owningLinks, owningLinks.contains(where: { url.starts(with: $0) }) else { continue }
            do {
                let link = try await source.handleURL(url: url)
                guard let link else { continue }
                results.append((link, source.id))
            } catch {
                Logger.shared.error(error, "\(source.id)| Handle Deep Link")
            }
        }

        for tracker in trackers {
            guard tracker.intents.canHandleURL ?? false else { continue }

            guard let owningLinks = tracker.config?.owningLinks, owningLinks.contains(where: { url.starts(with: $0) }) else { continue }
            do {
                let link = try await tracker.handleURL(url: url)
                guard let link else { continue }
                results.append((link, tracker.id))
            } catch {
                Logger.shared.error(error, "\(tracker.id)| Handle Deep Link")
            }
        }
        return results
    }

    @discardableResult
    func handleURL(for url: URL) async -> Bool {
        await MainActor.run {
            ToastManager.shared.loading = true
        }
        let results = await handleDeepLink(for: url.relativeString)
        await MainActor.run {
            ToastManager.shared.loading = false
        }
        if results.isEmpty {
            return false
        }
        if results.count == 1 {
            let (link, sourceID) = results.first!

            Task { @MainActor [weak self] in
                await self?.didTriggerDeepLinkAction(link, for: sourceID)
            }
            return true
        }

        // Show Alert
        let alert = await UIAlertController(title: "Handler", message: "Choose Handler", preferredStyle: .actionSheet)

        // Add Actions
        for (link, sourceID) in results {
            guard let source = await getSource(id: sourceID) else {
                continue
            }
            // Add Action
            let action = await UIAlertAction(title: source.name, style: .default) { _ in
                Task { @MainActor [weak self] in
                    await self?.didTriggerDeepLinkAction(link, for: sourceID)
                }
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

    @MainActor
    func didTriggerDeepLinkAction(_ link: DSKCommon.DeepLinkContext, for sourceID: String) async {
        if let highlight = link.content {
            NavigationModel.shared.content = .init(from: highlight, with: sourceID)
        } else if let readerContext = link.read {
            await StateManager.shared.openReader(context: readerContext, caller: readerContext.content, source: sourceID)
        } else if let link = link.link {
            NavigationModel.shared.link = .init(sourceID: sourceID, link: link)
        }
    }
}
