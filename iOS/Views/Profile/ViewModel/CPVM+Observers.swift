//
//  CPVM+Observers.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import Foundation

fileprivate typealias ViewModel = ProfileView.ViewModel
extension ViewModel {

    func setupObservers() async {
        let actor = await RealmActor.shared()

        // Observe Progress Markers
        let id = identifier
        progressToken = await actor
            .observeReadChapters(for: id) { [weak self] value in
                self?.readChapters = value
                Task { [weak self] in
                    await self?.setActionState()
                }
            }

        // Observe Library
        libraryTrackingToken = await actor
            .observeLibraryState(for: id) { [weak self] value in
                self?.inLibrary = value
            }

        // Observe Saved For Later
        readLaterToken = await actor
            .observeReadLaterState(for: id) { [weak self] value in
                self?.savedForLater = value
            }

        // Observe Downloads
        downloadTrackingToken = await actor
            .observeDownloadStatus(for: id) { [weak self] value in
                self?.downloads = value
            }
        
        // Observe Chapter Bookmarks
        chapterBookmarkToken = await actor
            .observeChapterBookmarks({ value in
                Task { @MainActor [weak self] in
                    self?.bookmarkedChapters = value
                }
            })
    }

    func removeNotifier() {
        currentMarkerToken?.invalidate()
        currentMarkerToken = nil

        progressToken?.invalidate()
        progressToken = nil

        downloadTrackingToken?.invalidate()
        downloadTrackingToken = nil

        libraryTrackingToken?.invalidate()
        libraryTrackingToken = nil

        readLaterToken?.invalidate()
        readLaterToken = nil
        
        chapterBookmarkToken?.invalidate()
        chapterBookmarkToken = nil
    }
}
