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
        @ObservedResults(LibraryCollection.self) var collections
        @ObservedResults(LibraryEntry.self) var libraryEntries
        @EnvironmentObject var storedContent: StoredContent
        private typealias AddCollectionView = LibraryView.ManageCollectionsView.AddCollectionView

        @State var flag: LibraryFlag = .unknown
        @State var selectedCollections = Set<String>()
        var entry: LibraryEntry? {
            libraryEntries.first { $0._id == storedContent._id }
        }

        func containsCollection(withID id: String) -> Bool {
            entry?.collections.contains(id) ?? false
        }

        @Environment(\.presentationMode) var presentationMode
        var CollectionLabelName: String {
            if let entry = entry {
                let collectionNames = entry.collections.compactMap { id in
                    collections.first(where: { $0._id == id })?.name
                }.joined(separator: ", ")
                return collectionNames
            } else {
                return "None"
            }
        }

        var body: some View {
            NavigationView {
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

                .animation(.default, value: collections)
                .animation(.default, value: libraryEntries)
                .animation(.default, value: entry)
                .navigationTitle("Manage")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
                .onAppear {
                    flag = entry?.flag ?? .unknown
                    // Prune Deleted Collections
                    let realm = try! Realm()
                    guard let entry = entry?.thaw() else {
                        return
                    }
                    var collecs = entry.collections.toArray()
                    collecs = collecs.filter(isValidCollection(_:))
                    try! realm.safeWrite {
                        entry.collections.removeAll()
                        entry.collections.append(objectsIn: collecs)
                    }
                }
            }
        }

        func isValidCollection(_ id: String) -> Bool {
            collections.contains(where: { $0._id == id })
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
                Section {
                    AddCollectionView()
                } header: {
                    Text("Create")
                }
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
                    DataManager.shared.clearCollections(for: entry)
                } label: {
                    Label("Remove from all collections.", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    DataManager.shared.toggleLibraryState(for: storedContent)
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
                if let entry = entry {
                    DataManager.shared.setReadingFlag(for: entry, to: newValue)
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
            Button { toggleCollection(id: collection._id) } label: {
                HStack {
                    Text(collection.name)
                    Spacer()

                    if containsCollection(withID: collection._id) {
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
            DataManager.shared.toggleCollection(for: entry, withId: id)
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
