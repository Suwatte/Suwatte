//
//  CPVM+ChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation
import SwiftUI

private typealias ViewModel = ProfileView.ViewModel



extension ViewModel {
    func getPreviewChapters(for statement: ChapterStatement) -> [ThreadSafeChapter] {
        let chapters = statement.filtered
        let targets = chapters.count >= 5 ? Array(chapters[0 ... 4]) : Array(chapters[0...])
        return targets
    }
}



extension ViewModel {
    
    // O(n)
    func prepareChapterStatement(_ chapters: [ThreadSafeChapter], content: SimpleContentInfo) -> ChapterStatement {
        var maxOrderKey: Double = 0
        var distinctKeys = Set<Double>()
        
        let filtered = STTHelpers.filterChapters(chapters, with: sourceID) { chapter in
            let orderKey = chapter.chapterOrderKey
            maxOrderKey = max(orderKey, maxOrderKey)
            distinctKeys.insert(orderKey)
        }
        
        let distinctCount = distinctKeys.count
        return .init(content: content, filtered: filtered, originalList: chapters, distinctCount: distinctCount, maxOrderKey: maxOrderKey)
    }
    
    func getSortedChapters(_ chapters: [ThreadSafeChapter], onlyDownloaded: Bool, method: ChapterSortOption, descending: Bool) async -> [ThreadSafeChapter] {
        return await BGActor.run {
            func sort(_ chapters: [ThreadSafeChapter]) -> [ThreadSafeChapter] {
                switch method {
                case .date:
                    return chapters
                        .sorted(by: \.date, descending: descending)
                case .source:
                    return chapters
                        .sorted(by: \.index, descending: !descending) // Reverese Source Index
                case .number:
                    return chapters
                        .sorted(by: \.chapterOrderKey, descending: descending) // Reverese Source Index
                }
            }

            if onlyDownloaded {
                let filtered = sort(chapters
                    .filter { downloads[$0.id] == .completed })

                return filtered
            }

            let data = sort(chapters)

            return data
        }
    }
    
    func getCurrentStatement() -> ChapterStatement {
        chapterMap[currentChapterSection] ?? .init(content: contentInfo, filtered: [], originalList: [], distinctCount: 0, maxOrderKey: 0)
    }
    
    func updateCurrentStatement(){
        let current = getCurrentStatement()
        let statement = prepareChapterStatement(current.originalList, content: current.content)
        withAnimation {
            chapterMap[current.content.id] = statement
        }
        Task {
            await setActionState()
        }
    }
    
}
