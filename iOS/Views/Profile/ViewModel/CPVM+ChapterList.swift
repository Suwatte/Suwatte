//
//  CPVM+ChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation

private typealias ViewModel = ProfileView.ViewModel

extension ViewModel {
    func getFilteredChapters(onlyDownloads: Bool, sortMethod: ChapterSortOption, desc: Bool) {
        let linked = linked
        let id = currentChapterSection

        let chapters = id == sourceID ? self.chapters : linked
            .first(where: { $0.source.id == id })?
            .chapters ?? []

        guard !chapters.isEmpty else { return }
        let downloads = self.downloads

        Task {
            await BGActor.run { [weak self] in

                func sort(_ chapters: [ThreadSafeChapter]) -> [ThreadSafeChapter] {
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
                    await self?.animate { [weak self] in
                        self?.chapterListChapters = filtered
                    }
                    return
                }

                let data = sort(STTHelpers.filterChapters(chapters, with: id))

                await self?.animate { [weak self] in
                    self?.chapterListChapters = data
                }
            }
        }
    }
}
