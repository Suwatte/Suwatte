//
//  CPVM+ContentLink.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    // Handles the addition on linked chapters
    func resolveLinks() async {
        let id = identifier
        let actor = await RealmActor.shared()
        // Contents that this title is linked to
        let entries = await actor
            .getLinkedContent(for: id)

        linkedContentIDs = entries
            .map(\.id)

        // Ensure there are linked titles
        guard !entries.isEmpty, !Task.isCancelled else { return }

        await withTaskGroup(of: Void.self, body: { [weak self] group in
            for entry in entries {
                group.addTask { [weak self] in
                    await self?.getChapterSection(for: entry)
                }
            }
        })
    }

    func getChapterSection(for content: StoredContent) async {
        let source = await DSK.shared.getSource(id: content.sourceId)
        guard let source else { return }
        do {
            let chapters = try await source.getContentChapters(contentId: content.contentId)
            let prepared = chapters
                .sorted(by: \.index, descending: false)
                .map { $0.toThreadSafe(sourceID: content.sourceId, contentID: content.contentId) }

            Task {
                let actor = await RealmActor.shared()
                let stored = prepared
                    .map { $0.toStored() }
                await actor.storeChapters(stored)
            }

            let statement = prepareChapterStatement(prepared,
                                                    content: .init(runnerID: source.id, runnerName: source.name, contentName: content.title, id: content.id, highlight: content.toHighlight()))

            await animate { [weak self] in
                self?.chapterMap[content.id] = statement
            }
        } catch {
            Logger.shared.error(error, source.id)
        }
    }

    func updateContentLinks() async {
        let actor = await RealmActor.shared()
        let titles = await actor.getLinkedContent(for: identifier)
        let newLinked = Set(titles.map(\.id))
        let currentLinked = Set(linkedContentIDs)
        linkedContentIDs = Array(newLinked)

        let removed = currentLinked.subtracting(newLinked) // Present in Current Linked but not in newLinked
        let added = newLinked.subtracting(currentLinked) // Present in New linked but not in current linked

        // Remove Unlinked Titles
        for content in removed {
            await animate { [weak self] in
                self?.chapterMap.removeValue(forKey: content)
            }
        }

        guard !added.isEmpty else { return }

        // Add Newly Linked Titles
        await withTaskGroup(of: Void.self, body: { group in
            for content in added {
                guard let title = titles.first(where: { $0.id == content }) else { continue }
                group.addTask { [weak self] in
                    await self?.getChapterSection(for: title)
                }
            }
        })

        // Re Sync With All Parties
        await handleSync()
    }
}

extension Sequence {
    func max<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        return self.max { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}
