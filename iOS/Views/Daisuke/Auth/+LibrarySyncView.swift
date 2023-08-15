//
//  +LibrarySyncView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import RealmSwift
import SwiftUI

extension DSKAuthView {
    struct LibrarySyncView: View {
        var source: AnyContentSource
        @State var presentConfimationAlert = false

        var body: some View {
            Button {
                presentConfimationAlert.toggle()
            } label: {
                Label("Sync Library", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
            .alert("Sync Library", isPresented: $presentConfimationAlert, actions: {
                Button("Cancel", role: .cancel) {}
                Button("Proceed") { call() }
            }, message: {
                Text("Are you sure you want to proceed?")
            })
        }

        func call() {
            Task {
                ToastManager.shared.loading = true
                do {
                    try await handleContentSync()
                } catch {
                    Logger.shared.error("\(error)")
                    ToastManager.shared.error(error)
                }
                ToastManager.shared.loading = false
            }
        }
    }
}

extension DSKAuthView.LibrarySyncView {
    func handleContentSync() async throws {
        let actor = await RealmActor()
        let library = await actor.getUpSync(for: source.id)
        let downSynced = try await source.syncUserLibrary(library: library)
        
        await actor.downSyncLibrary(entries: downSynced, sourceId: source.id)
        ToastManager.shared.info("Synced!")
    }
}
