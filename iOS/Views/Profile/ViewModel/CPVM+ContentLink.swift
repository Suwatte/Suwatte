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
            for (index, entry) in entries.enumerated() {
                group.addTask { [weak self] in
                    await self?.initializeLinkedChapterSection(for: entry, loadChapters: false, index: index)
                }
            }
        })
    }

    private func getChaptersForLinkedTitle(source: AnyContentSource, contentId: String, sourceId: String) async -> [ThreadSafeChapter] {
        do {
            var chapters = try await source.getContent(id: contentId).chapters ?? []
            if chapters.isEmpty {
                chapters = try await source.getContentChapters(contentId: contentId)
            }

            let prepared = chapters
                .sorted(by: \.index, descending: false)
                .map { $0.toThreadSafe(sourceID: sourceId, contentID: contentId) }

            Task {
                let actor = await RealmActor.shared()
                let stored = prepared
                    .map { $0.toStored() }
                await actor.storeChapters(stored)
            }

            return prepared
        } catch {
            Logger.shared.error(error, source.id)
        }

        return []
    }

    func loadLinkedChapters() async {
        let current = getCurrentStatement()
        if !current.originalList.isEmpty {
            await animate { [weak self] in
                self?.chapterState = .loaded(true)
            }
            return
        }

        let source = await DSK.shared.getSource(id: current.content.runnerID)
        guard let source else { return }

        await getChapterStatement(source: source, contentInfo: current.content, loadChapters: true, index: current.index)
    }

    private func getChapterStatement(source: AnyContentSource, contentInfo: SimpleContentInfo, loadChapters: Bool, index: Int) async {
        let prepared = !loadChapters
            ? []
            : await getChaptersForLinkedTitle(source: source, contentId: contentInfo.contentIdentifier.contentId, sourceId: contentInfo.contentIdentifier.sourceId)

        let statement = prepareChapterStatement(prepared, content: contentInfo, loadChapters: loadChapters, index: index)

        await animate { [weak self] in
            self?.chapterMap[contentInfo.contentIdentifier.id] = statement
            self?.chapterState = .loaded(true)
        }
    }

    func initializeLinkedChapterSection(for content: StoredContent, loadChapters: Bool, index: Int) async {
        let source = await DSK.shared.getSource(id: content.sourceId)
        guard let source else { return }

        let contentInfo: SimpleContentInfo = .init(runnerID: source.id, runnerName: source.name, contentName: content.title, contentIdentifier: content.ContentIdentifier, highlight: content.toHighlight())

        await getChapterStatement(source: source, contentInfo: contentInfo, loadChapters: loadChapters, index: index)
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
            for (index, content) in added.enumerated() {
                guard let title = titles.first(where: { $0.id == content }) else { continue }
                group.addTask { [weak self] in
                    await self?.initializeLinkedChapterSection(for: title, loadChapters: false, index: index)
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
