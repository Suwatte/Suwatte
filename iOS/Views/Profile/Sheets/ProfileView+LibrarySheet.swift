//
//  ProfileView+LibrarySheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-21.
//

import Foundation
import RealmSwift
import SwiftUI

extension ProfileView {
    struct Sheets {}
}

extension ProfileView.Sheets {
    struct LibrarySheet: View {
        private typealias AddCollectionView = LibraryView.ManageCollectionsView.AddCollectionView
        let id: String
        @State private var flag: LibraryFlag = .unknown
        @State private var selectedCollections = Set<String>()
        @State private var entry: LibraryEntry?

        @EnvironmentObject private var stateManager: StateManager

        private var collections: [LibraryCollection] {
            stateManager.collections
        }

        func containsCollection(withID id: String) -> Bool {
            selectedCollections.contains(id)
        }

        @Environment(\.presentationMode) var presentationMode
        var CollectionLabelName: String {
            guard let entry else { return "None" }
            let collectionNames = entry.collections.compactMap { id in
                collections.first(where: { $0.id == id })?.name
            }.joined(separator: ", ")
            return collectionNames
        }

        var body: some View {
            SmartNavigationView {
                Group {
                    if entry != nil {
                        List {
                            Section {
                                // Collections
                                CollectionView
                                // Content Flag
                                ContentFlags
                            } header: {
                                Text("Manage")
                            }
                            .headerProminence(.increased)

                            // Delete Section
                            DeleteSection
                        }
                    } else {
                        ProgressView()
                    }
                }
                .animation(.default, value: collections)
                .animation(.default, value: entry)
                .animation(.default, value: selectedCollections)
                .navigationTitle("Manage")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
                .task {
                    let actor = await RealmActor.shared()
                    let value = await actor.fetchAndPruneLibraryEntry(for: id)
                    Task { @MainActor in
                        entry = value
                        selectedCollections = Set(value?.collections.toArray() ?? [])
                        flag = value?.flag ?? .unknown
                    }
                }
            }
        }

        func isValidCollection(_ id: String) -> Bool {
            collections.contains(where: { $0.id == id })
        }

        var CollectionView: some View {
            NavigationLink {
                List {
                    // Add New Collection
                    ANC
                    // Main Management Section
                    MainSection
                }
                .navigationTitle("Collections")
            } label: {
                STTLabelView(title: "Collections", label: CollectionLabelName)
            }
        }

        // MARK: Main

        @ViewBuilder
        var ANC: some View {
            if collections.count < 3 {
                AddCollectionView()
            }
        }

        @ViewBuilder
        var MainSection: some View {
            Section {
                if collections.isEmpty {
                    NoCollectionsView
                } else {
                    CollectionsView
                }
            } header: {
                Text("Manage")
            }
        }

        var DeleteSection: some View {
            Section {
                Button(role: .destructive) {
                    guard let entry = entry else {
                        return
                    }
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.clearCollections(for: entry.id)
                    }
                } label: {
                    Label("Remove from all collections.", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    guard let ci = entry?.content?.ContentIdentifier else { return }
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.toggleLibraryState(for: ci)
                    }
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Label("Remove from library", systemImage: "folder.badge.minus")
                }
            } header: {
                Text("Remove")
            }
            .headerProminence(.increased)
        }

        @ViewBuilder
        var ContentFlags: some View {
            Picker("Reading Flag", selection: $flag) {
                ForEach(LibraryFlag.allCases) { data in
                    Text(data.description)
                        .tag(data)
                }
            }
            .pickerStyle(.automatic)
            .onChange(of: flag) { newValue in
                guard let entry else { return }
                Task {
                    let actor = await RealmActor.shared()
                    await actor.setReadingFlag(for: entry.id, to: newValue)
                }
            }
        }

        // MARK: Child Views

        var CollectionsView: some View {
            ForEach(collections) { collection in
                CollectionCell(for: collection)
            }
        }

        func CollectionCell(for collection: LibraryCollection) -> some View {
            Button { toggleCollection(id: collection.id) } label: {
                HStack {
                    Text(collection.name)
                    Spacer()

                    if containsCollection(withID: collection.id) {
                        Image(systemName: "checkmark")
                            .transition(.scale)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        func toggleCollection(id: String) {
            guard let entry = entry else {
                return
            }
            let contentID = entry.id
            let collectionID = id
            Task { @MainActor in
                if selectedCollections.contains(id) {
                    selectedCollections.remove(id)
                } else {
                    selectedCollections.insert(id)
                }
            }
            Task {
                let actor = await RealmActor.shared()
                await actor.toggleCollection(for: contentID, withId: collectionID)
            }
        }

        var NoCollectionsView: some View {
            HStack {
                Spacer()
                Text("No Collections Created.")
                Spacer()
            }
        }
    }
}
