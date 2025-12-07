//
//  SDV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import RealmSwift
import SwiftUI

extension SourceDownloadView {
    final class ViewModel: ObservableObject {
        @Published var entries = [SourceDownloadIndex]()
        @Published var working = true
        @Published var text = ""
        @Published var initialFetchComplete = false

        private var token: NotificationToken?
    }
}

extension SourceDownloadView.ViewModel {
    func watch(_ sort: SourceDownloadView.SortOption, _ ascending: Bool) async {
        await MainActor.run {
            stop()
            withAnimation {
                working = true
            }
        }

        let actor = await RealmActor.shared()

        token = await actor
            .observeDownloads(query: text.trimmingCharacters(in: .whitespacesAndNewlines),
                              ascending: ascending,
                              sort: sort)
            { value in
                Task { @MainActor [weak self] in
                    self?.entries = value
                    self?.working = false
                    self?.initialFetchComplete = true
                }
            }
    }

    func stop() {
        token?.invalidate()
        token = nil
    }
}
