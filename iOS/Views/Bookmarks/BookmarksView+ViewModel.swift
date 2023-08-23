//
//  BookmarksView+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-22.
//

import Foundation
import RealmSwift
import SwiftUI

extension BookmarksView {
    final class ViewModel: ObservableObject {
        private var token: NotificationToken?
        @MainActor @Published var results: [UpdatedBookmark]?

        func observe(id: String) async {
            let actor = await RealmActor()

            token = await actor
                .observeBookmarks(for: id) { [weak self] bookmarks in
                    self?.setValues(bookmarks)
                }
        }

        func setValues(_ data: [UpdatedBookmark]) {
            Task { @MainActor in
                withAnimation {
                    results = data
                }
            }
        }

        func stop() {
            token?.invalidate()
            token = nil
        }
    }
}
