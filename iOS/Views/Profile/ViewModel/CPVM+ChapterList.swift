//
//  CPVM+ChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func getFilteredChapters(onlyDownloads: Bool, sortMethod: ChapterSortOption?, desc: Bool) async -> [ThreadSafeChapter] {
        let linked = linked
        let id = currentChapterSection

        let chapters = id == sourceID ? self.chapters : linked
            .first(where: { $0.source.id == id })?
            .chapters ?? []

        guard !chapters.isEmpty else { return [] }
        let downloads = self.downloads

        return await BGActor.run {
            func sort(_ chapters: [ThreadSafeChapter]) -> [ThreadSafeChapter] {
                guard let sortMethod else { return chapters }
                switch sortMethod {
                case .date:
                    return chapters
                        .sorted(by: \.date, descending: desc)
                case .source:
                    return chapters
                        .sorted(by: \.index, descending: !desc) // Reverese Source Index
                case .number:
                    return chapters
                        .sorted(by: \.chapterOrderKey, descending: desc) // Reverese Source Index
                }
            }

            if onlyDownloads {
                let filtered = sort(chapters
                    .filter { downloads[$0.id] == .completed })

                return filtered
            }

            let data = sort(STTHelpers.filterChapters(chapters, with: id))

            return data
        }
    }

    func prepareChapterList(onlyDownloads: Bool, sortMethod: ChapterSortOption, desc: Bool) {
        Task { [weak self] in
            let chapters = await self?.getFilteredChapters(onlyDownloads: onlyDownloads, sortMethod: sortMethod, desc: desc)
            guard let chapters else { return }
            await animate { [weak self] in
                self?.chapterListChapters = chapters
            }
        }
    }

    func preparePreview() async {
        let chapters = await getFilteredChapters(onlyDownloads: false, sortMethod: .source, desc: true)
        let targets = chapters.count >= 5 ? Array(chapters[0 ... 4]) : Array(chapters[0...])
        await animate { [weak self] in
            self?.previewChapters = targets
            self?.chapterListChapters = chapters
        }
    }
}
