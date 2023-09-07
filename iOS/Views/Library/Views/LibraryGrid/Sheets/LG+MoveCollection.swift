//
//  LG+MoveCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import RealmSwift
import SwiftUI

extension LibraryView.LibraryGrid {
    struct MoveCollectionsView: View {
        var entries: [LibraryEntry]
        @EnvironmentObject var model: ViewModel
        @Environment(\.presentationMode) var presentationMode
        @State var selectedCollections = [String]()
        @ObservedObject var toastManager = ToastManager()
        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection] {
            stateManager.collections
        }

        var body: some View {
            SmartNavigationView {
                List {
                    Section {
                        ForEach(collections) { collection in
                            Button { onSelection(of: collection) } label: {
                                HStack {
                                    Text(collection.name)
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .opacity(selectedCollections.contains(collection.id) ? 1.0 : 0.0)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Move to...")
                    }

                    Section {
                        Button("Reset") { withAnimation {
                            selectedCollections.removeAll()
                        }}
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Select Collections")
                .navigationBarTitleDisplayMode(.inline)
                .toast()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            ToastManager.shared.loading.toggle()
                            let targets = zip(entries.indices, entries)
                                .filter { model.selectedIndexes.contains($0.0) }
                                .map { $0.1.id }
                            Task {
                                let actor = await Suwatte.RealmActor.shared()
                                await actor.moveToCollections(entries: Set(targets), cids: selectedCollections)
                            }
                            ToastManager.shared.loading.toggle()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }

        func onSelection(of collection: LibraryCollection) {
            withAnimation {
                if selectedCollections.contains(collection.id) {
                    selectedCollections.remove(at: selectedCollections.firstIndex(of: collection.id)!)
                } else {
                    selectedCollections.append(collection.id)
                }
            }
        }
    }
}
