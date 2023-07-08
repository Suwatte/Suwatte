//
//  +LibrarySyncView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import SwiftUI
import RealmSwift

extension DSKAuthView {
    
    struct LibrarySyncView : View {
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
        let library = DataManager.shared.getUpSync(for: source.id)
        let downSynced = try await source.syncUserLibrary(library: library)
        DataManager.shared.downSyncLibrary(entries: downSynced, sourceId: source.id)
        await MainActor.run(body: {
            ToastManager.shared.info("Synced!")
        })
    }
}

extension DataManager {
    func getUpSync(for id: String) -> [DSKCommon.UpSyncedContent] {
        let realm = try! Realm()
        
        let library: [DSKCommon.UpSyncedContent] = realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == id }
            .where { $0.content != nil }
            .map { .init(id: $0.content!.contentId, flag: $0.flag) }
        return library
    }
}
