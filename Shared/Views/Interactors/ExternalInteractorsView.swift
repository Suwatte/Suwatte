//
//  ExternalInteractorsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-27.
//

import SwiftUI

struct ExternalInteractorsView: View {
    @ObservedObject var engine = DaisukeEngine.shared

    @State var showAddSheet = false
    var body: some View {
        List {
            SourcesSection
        }
        .navigationTitle("External Interactors")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("\(Image(systemName: "plus"))") {
                    showAddSheet.toggle()
                }
            }
        }
        .fileImporter(isPresented: $showAddSheet, allowedContentTypes: [.init(filenameExtension: "stt")!]) { result in

            guard let path = try? result.get() else {
                ToastManager.shared.setError(msg: "Task Failed")
                return
            }

            if path.startAccessingSecurityScopedResource() {
//                let success = engine.shared.importInteractor(from: path, deleteOriginal: false)
//                // Copy To Local Document
//                if success {
//                    ToastManager.shared.setComplete(title: "Added!")
//                } else {
//                    ToastManager.shared.setToast(toast: .init(displayMode: .alert, type: .error(.red), title: "Failed to Import"))
//                }
            }

            path.stopAccessingSecurityScopedResource()
        }
    }

    var SourcesSection: some View {
        Section {
            ForEach(engine.getSources()) { interactor in
                NavigationLink(interactor.name) {
                    Text("MENU")
//                    InteractorMenuView(interactor: interactor)
                }
                .swipeActions {
                    Button("Remove") {
//                        engine.shared.removeInteractor(with: interactor.id)
                    }
                    .tint(.red)
                }
            }

        } header: {
            Text("Sources")
        }
    }
}
