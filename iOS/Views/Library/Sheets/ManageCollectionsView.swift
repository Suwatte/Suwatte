//
//  ManageCollectionsView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-08.
//

import RealmSwift
import SwiftUI

extension LibraryView {
    struct ManageCollectionsView: View {
        @Environment(\.presentationMode) private var presentationMode
        @EnvironmentObject private var model: StateManager

        @State private var editMode = EditMode.inactive

        var collections: [LibraryCollection] {
            model.collections
        }

        var body: some View {
            SmartNavigationView {
                List {
                    AdditionSection
                    EditorSection
                }
                .navigationTitle("Collections")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(content: { EditButton() })
                .closeButton()
                .animation(.default, value: collections)
                .environment(\.editMode, $editMode)
            }
        }
    }
}

private typealias MCV = LibraryView.ManageCollectionsView
extension MCV {
    var AdditionSection: some View {
        AddCollectionView()
    }
}

extension MCV {
    var EditorSection: some View {
        Section {
            ForEach(collections) { collection in
                NavigationLink {
                    Form {
                        CollectionManagementView(collection: collection, collectionName: collection.name)
                    }
                } label: {
                    Text(collection.name)
                }
            }
            .onDelete(perform: delete)
            .onMove(perform: move)
        } header: {
            Text("Collections")
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var arr = collections.map(\.id) as [String]
        arr.move(fromOffsets: source, toOffset: destination)

        Task {
            let actor = await RealmActor.shared()
            await actor.reorderCollections(arr)
        }
    }

    func delete(from idxs: IndexSet) {
        let ids = idxs.compactMap { collections.getOrNil($0)?.id }
        for id in ids {
            Task {
                let actor = await RealmActor.shared()
                await actor.deleteCollection(id: id)
            }
        }
    }
}

extension MCV {
    struct AddCollectionView: View {
        @State var name: String = ""

        var body: some View {
            Section {
                TextField("Collection Name", text: $name)
                    .onSubmit {
                        addCollection()
                    }
                HStack {
                    Spacer()
                    Button("Add Collection") { addCollection() }
                        .buttonStyle(.bordered)
                    Spacer()
                }

            } header: {
                Text("New Collection")
            }
        }

        func addCollection() {
            if name.isEmpty {
                return
            }
            let val = name
            name = ""
            Task {
                let actor = await RealmActor.shared()
                await actor.addCollection(withName: val)
            }
        }
    }
}

// MARK: Edit View

extension MCV {
    struct CollectionEditView: View {
        @State var name: String
        var collection: LibraryCollection
        @State var showDone = false
        @Binding var editting: Bool
        var body: some View {
            HStack {
                TextField("Enter Name", text: $name, onEditingChanged: { change in
                    if change {
                        withAnimation {
                            editting = false
                            showDone = true
                        }
                    } else {
                        withAnimation {
                            showDone = false
                        }
                    }

                })
                if showDone {
                    Button("Done") {
                        if !name.isEmpty {
                            Task {
                                let actor = await RealmActor.shared()
                                await actor.renameCollection(collection.id, name)
                            }
                        }
                        resign()
                    }
                }
            }
        }

        @MainActor
        func resign() {
            withAnimation {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showDone = false
                editting = true
            }
        }
    }
}
