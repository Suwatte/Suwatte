//
//  CPVM+ChapterList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation

fileprivate typealias ViewModel = ProfileView.ViewModel


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
                var base = chapters
                
                if onlyDownloads {
                    let filtered = sort(chapters
                        .filter { downloads[$0.id] == .completed })
                    await self?.animate { [weak self] in
                        self?.chapterListChapters = filtered
                    }
                    return
                }
                
                let languages = Preferences.standard.globalContentLanguages
                let blacklisted = self?.getBlacklistedProviders(for: id)
                
                
                // By Language
                if !languages.isEmpty {
                    func lang(_ chapter: ThreadSafeChapter) -> Bool {
                        languages.contains(where: { $0
                            .lowercased()
                            .starts(with: chapter.language.lowercased()) })
                    }
                    base = base
                        .filter(lang(_:))
                }
                
                // By Provider
                if let blacklisted, !blacklisted.isEmpty {
                    func provider(_ chapter: ThreadSafeChapter) -> Bool {
                        let providers = chapter.providers?.map(\.id) ?? []
                        if providers.isEmpty { return true }
                        return providers.allSatisfy({ !blacklisted.contains($0) })
                    }
                    base = base
                        .filter(provider(_:))
                }
                
                let final = sort(chapters)
                await self?.animate { [weak self] in
                    self?.chapterListChapters = final
                }
            }
        }
    }
    
}

extension ViewModel {
    func getBlacklistedProviders(for id: String) -> [String] {
        let defaults = UserDefaults.standard
        
        return defaults.stringArray(forKey: STTKeys.BlackListedProviders(id)) ?? []
    }
    
    func setBlackListedProviders(for id: String, values: [String]) {
        let values = Array(Set(values))
        UserDefaults.standard.setValue(values, forKey: STTKeys.BlackListedProviders(id))
    }
}
