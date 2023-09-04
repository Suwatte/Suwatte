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

        await withTaskGroup(of: ContentLinkSection?.self, body: { [weak self] group in
            for entry in entries {
                group.addTask { [weak self] in
                    await self?.getChapterSection(for: entry)
                }
            }

            for await result in group {
                guard let result else { continue }
                await self?.animate { [weak self] in
                    self?.linked.append(result)
                }
            }

        })
    }

    func getChapterSection(for content: StoredContent) async -> ContentLinkSection? {
        let source = await DSK.shared.getSource(id: content.sourceId)
        guard let source else { return nil }
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

            let maxOrderKey = prepared
                .max(by: \.chapterOrderKey)?
                .chapterOrderKey ?? 0

            return .init(source: source,
                         chapters: prepared,
                         maxOrderKey: maxOrderKey)

        } catch {
            Logger.shared.error(error, source.id)
        }

        return nil
    }

    func updateContentLinks() async {
        let actor = await RealmActor.shared()
        let newLinked = await actor.getLinkedContent(for: identifier).map(\.id)
        guard newLinked != linkedContentIDs else { return }
        await MainActor.run { [weak self] in
            self?.contentState = .idle
            self?.chapterState = .idle
        }
    }
}

extension Sequence {
    func max<T: Comparable>(by keyPath: KeyPath<Element, T>) -> Element? {
        return self.max { a, b in
            a[keyPath: keyPath] < b[keyPath: keyPath]
        }
    }
}
