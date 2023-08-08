//
//  ImageViewer+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Foundation
import SwiftUI

struct CurrentViewerState: Hashable {
    var chapter: ThreadSafeChapter
    var page: Int
    var progress: Double
}

@MainActor
final class IVViewModel: ObservableObject {
    /// Keeps track of the  current viewer state
    @Published var viewerState: CurrentViewerState?
    
    /// Keeps track of the load state of each chapter
    @Published var loadState: [String: Loadable<Bool>] = [:]
    
    /// Keeps track of the initial presentation state
    @Published var presentationState : Loadable<Bool> = .idle
    
    /// Controls the sheets that appear
    @Published var control: MenuControl = .init()
    
    let dataCache = IVDataCache()
    
    func consume(_ value: InitialIVState) async {
        let requested = value.openTo.toThreadSafe()
        presentationState = .loading

        let chapters = value.chapters

        // Sort Chapters
        let useIndex = chapters.map { $0.index }.reduce(0, +) > 0
        let sorted =  useIndex ? chapters.sorted(by: { $0.index > $1.index }) : chapters.sorted(by: { $0.number > $1.number })

        // Set Chapters
        await dataCache.setChapters(sorted.map { $0.toThreadSafe() })
                 
        // Load Initial Chapter
        do {
            try await dataCache.load(for: requested)
            updateChapterState(requested.id, state: .loaded(true))
            await MainActor.run {
                withAnimation {
                    presentationState = .loaded(true)
                }
            }
        } catch {
            updateChapterState(requested.id, state: .failed(error))
            Logger.shared.error(error, "Reader")
            await MainActor.run {
                withAnimation {
                    presentationState = .failed(error)
                }
            }
        }
        
    }
    
    @MainActor
    func updateChapterState(_ id: String, state: Loadable<Bool>) {
        loadState.updateValue(state, forKey: id)
    }
    
}
