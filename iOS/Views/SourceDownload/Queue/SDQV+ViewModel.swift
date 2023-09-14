//
//  SDQV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-26.
//

import Foundation
import RealmSwift
import SwiftUI

extension SourceDownloadQueueView {
    final class ViewModel: ObservableObject {
        @Published var isWorking = true
        @Published var data = [[SourceDownload]]()
        @Published var initialDataFetchComplete = false
        private var token: NotificationToken?
    }
}

extension SourceDownloadQueueView.ViewModel {
    func watch() async {
        await MainActor.run {
            stop()
            isWorking = true
        }
        let actor = await RealmActor.shared()
        token = await actor
            .observeDownloadsQueue { value in
                Task { @MainActor [weak self] in
                    self?.data = value
                    self?.initialDataFetchComplete = true
                    self?.isWorking = false
                }
            }
    }

    func stop() {
        token?.invalidate()
        token = nil
    }
}
