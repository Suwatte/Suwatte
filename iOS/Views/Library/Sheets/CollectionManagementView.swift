//
//  CollectionManagementView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-31.
//

import RealmSwift
import SwiftUI

struct CollectionManagementView: View {
    @StateRealmObject var collection: LibraryCollection
    @State var collectionName: String
    @State var pinningType: TitlePinningType = .unread
    @State var enableFilters: Bool = false
    @State var enableTitlePinning: Bool = false

    @State var presentationState: Loadable<Bool> = .idle

    @ViewBuilder
    var filters: some View {
        Section {
            TextField("Collection Name", text: $collectionName)
        } header: {
            Text("Collection Name")
        }

        Section {
            Toggle("Pin Titles", isOn: $enableTitlePinning.animation())
            if enableTitlePinning {
                HStack {
                    Text("Pin Type")
                    Spacer()
                    Picker("", selection: $pinningType) {
                        ForEach(TitlePinningType.pinTypes, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        } header: {
            Text("Pinning")
        }

        Section {
            Toggle("Enable Smart Filters", isOn: $enableFilters.animation())

        } header: {
            Text("Smart Filters")
        }

        if let filter = collection.filter, enableFilters {
            FilterSections(collectionId: collection.id,
                           currentFilterID: collection.filter?.id,
                           adultContent: filter.adultContent,
                           sourceSelections: filter.sources.toArray(),
                           flagSelections: filter.readingFlags.toArray(),
                           contentSelections: filter.contentType.toArray(),
                           titleContains: filter.textContains.toArray(),
                           tagContains: filter.tagContains.toArray(),
                           contentStatuses: filter.statuses.toArray(),
                           logicalOperator: filter.logicalOperator)
                .transition(.opacity)
        }
    }

    var body: some View {
        filters
            .onChange(of: pinningType, perform: { _ in
                if presentationState == .loaded(true) {
                    setTitlePinningType(pinningType)
                }
            })
            .onChange(of: enableTitlePinning, perform: { _ in
                if presentationState == .loaded(true) {
                    setTitlePinningType(enableTitlePinning ? .unread : TitlePinningType.none)
                }
            })
            .onChange(of: enableFilters, perform: handleToggleFilterEnabled)
            .onAppear(perform: load)
            .onSubmit {
                saveName(collectionName)
            }
            .task {
                presentationState = .loaded(true)
            }
            .navigationTitle("Collection Settings")
            .navigationBarTitleDisplayMode(.inline)
    }

    func saveName(_ str: String) {
        if str.isEmpty {
            collectionName = collection.name
            return
        }
        let id = collection.id
        Task {
            let actor = await RealmActor.shared()
            await actor.renameCollection(id, str)
        }
    }

    func load() {
        presentationState = .loading

        collectionName = collection.name
        enableFilters = collection.filter != nil
        if let pinType = collection.pinningType, pinningType != TitlePinningType.none {
            pinningType = pinType
        }
        enableTitlePinning = collection.pinningType != TitlePinningType.none && collection.pinningType != nil
    }
}

extension CollectionManagementView {
    struct FilterSections: View {
        let collectionId: String
        let currentFilterID: String?
        @State var adultContent = ContentSelectionType.both
        @State var sourceSelections: [String]
        @State var flagSelections: [LibraryFlag]
        @State var contentSelections: [ExternalContentType]
        @State var titleContains: [String]
        @State var tagContains: [String]
        @State var contentStatuses: [ContentStatus]
        @State var titleText = ""
        @State var tagText = ""
        @State var sources: [StoredRunnerObject] = []
        @State var logicalOperator = LogicalOperator.and

        var body: some View {
            LogicalOperatorSection
            AdultContentSection
            TitlesSection
            Section {
                // MARK: Content Status

                ContentStatusSection

                // MARK: Reading Flag

                ReadingFlagSection

                // MARK: Content Type

                ContentTypeSection
            }
            SourcesSection

                .onChange(of: adultContent) { _ in
                    saveAll()
                }
                .onChange(of: sourceSelections) { _ in
                    saveAll()
                }
                .onChange(of: flagSelections) { _ in
                    saveAll()
                }
                .onChange(of: contentSelections) { _ in
                    saveAll()
                }
                .onChange(of: tagContains) { _ in
                    saveAll()
                }
                .onChange(of: titleContains) { _ in
                    saveAll()
                }
                .onChange(of: contentStatuses) { _ in
                    saveAll()
                }
                .onChange(of: logicalOperator) { _ in
                    saveAll()
                }
                .task {
                    let actor = await RealmActor.shared()
                    sources = await actor.getSavedAndEnabledSources()
                }
        }
    }
}

extension CollectionManagementView.FilterSections {
    var AdultContentSection: some View {
        Section {
            NavigationLink {
                List {
                    ForEach(ContentSelectionType.allCases) { selection in
                        Button {
                            adultContent = selection
                        } label: {
                            HStack {
                                Text(selection.description)
                                Spacer()
                                if adultContent == selection {
                                    Image(systemName: "checkmark")
                                        .transition(.scale)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NeutralButtonStyle())
                    }
                }
                .animation(.default, value: adultContent)
                .navigationBarTitle("Adult Content")
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text("Adult Content")
            }
        }
    }

    var TitlesSection: some View {
        Section {
            NavigationLink {
                List {
                    Section {
                        TextField("String", text: $titleText)
                        Button("Add") {
                            titleContains.append(titleText)
                            titleText.removeAll()
                        }.disabled(titleText.isEmpty)
                    }

                    Section {
                        ForEach(titleContains) { query in
                            Text(query)
                        }
                        .onDelete(perform: removeTitles(at:))
                    }
                }
                .animation(.default, value: titleContains)
                .navigationTitle("Title or Sumamry Contains")

            } label: {
                Text("Title or Summary Contains")
            }
            NavigationLink {
                List {
                    Section {
                        TextField("String", text: $tagText)
                        Button("Add") {
                            tagContains.append(tagText)
                            tagText.removeAll()
                        }.disabled(tagText.isEmpty)
                    }

                    Section {
                        ForEach(tagContains) { tag in
                            Text(tag)
                        }
                        .onDelete(perform: removeTags(at:))
                    }
                }

                .animation(.default, value: tagContains)
                .navigationTitle("Tags")

            } label: {
                Text("Tag Contains")
            }
        }
    }

    var ContentStatusSection: some View {
        NavigationLink {
            List {
                ForEach(ContentStatus.allCases, id: \.hashValue) { c in
                    Button {
                        if contentStatuses.contains(c) { contentStatuses.removeAll(where: { $0 == c }) } else {
                            contentStatuses.append(c)
                        }
                    } label: {
                        HStack {
                            Text(c.description)
                            Spacer()
                            if contentStatuses.contains(c) {
                                Image(systemName: "checkmark")
                                    .transition(.scale)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NeutralButtonStyle())
                }
            }
            .animation(.default, value: contentStatuses)
            .navigationBarTitle("Content Status")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            Text("Content Status")
        }
    }

    var ReadingFlagSection: some View {
        NavigationLink {
            List {
                ForEach(LibraryFlag.allCases) { flag in
                    Button {
                        if flagSelections.contains(flag) { flagSelections.removeAll(where: { $0 == flag }) } else {
                            flagSelections.append(flag)
                        }
                    } label: {
                        HStack {
                            Text(flag.description)
                            Spacer()
                            if flagSelections.contains(flag) {
                                Image(systemName: "checkmark")
                                    .transition(.scale)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NeutralButtonStyle())
                }
            }
            .animation(.default, value: flagSelections)
            .navigationBarTitle("Reading Flags")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            Text("Reading Flags")
        }
    }

    var ContentTypeSection: some View {
        NavigationLink {
            List {
                ForEach(ExternalContentType.allCases) { c in
                    Button {
                        if contentSelections.contains(c) { contentSelections.removeAll(where: { $0 == c }) } else {
                            contentSelections.append(c)
                        }
                    } label: {
                        HStack {
                            Text(c.description)
                            Spacer()
                            if contentSelections.contains(c) {
                                Image(systemName: "checkmark")
                                    .transition(.scale)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NeutralButtonStyle())
                }
            }
            .animation(.default, value: contentSelections)
            .navigationBarTitle("Content Type")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            Text("Content Type")
        }
    }

    var SourcesSection: some View {
        Section {
            NavigationLink {
                List {
                    ForEach(Array(sources), id: \.id) { source in
                        Button {
                            if sourceSelections.contains(source.id) { sourceSelections.removeAll(where: { $0 == source.id }) } else {
                                sourceSelections.append(source.id)
                            }
                        } label: {
                            HStack {
                                Text(source.name)
                                Spacer()
                                if sourceSelections.contains(source.id) {
                                    Image(systemName: "checkmark")
                                        .transition(.scale)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NeutralButtonStyle())
                    }
                }
                .animation(.default, value: sourceSelections)
                .navigationBarTitle("Sources")
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Text("Sources")
            }
        }
    }

    var LogicalOperatorSection: some View {
        Section {
            HStack {
                Text("Logical Operator")
                Spacer()
                Picker("", selection: $logicalOperator) {
                    ForEach(LogicalOperator.allCases, id: \.self) {
                        Text($0.description)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        } footer: {
            Text("(AND) requires all applied filters to match. (OR) requires only one of the applied filters to match.")
        }
    }
}

extension CollectionManagementView.FilterSections {
    func removeTags(at offsets: IndexSet) {
        tagContains.remove(atOffsets: offsets)
    }

    func removeTitles(at offsets: IndexSet) {
        titleContains.remove(atOffsets: offsets)
    }

    func saveAll() {
        let filter = LibraryCollectionFilter()

        if let currentFilterID {
            filter.id = currentFilterID
        }
        filter.adultContent = adultContent
        filter.sources.append(objectsIn: sourceSelections)
        filter.readingFlags.append(objectsIn: flagSelections)
        filter.contentType.append(objectsIn: contentSelections)
        filter.tagContains.append(objectsIn: tagContains)
        filter.textContains.append(objectsIn: titleContains)
        filter.statuses.append(objectsIn: contentStatuses)
        filter.logicalOperator = logicalOperator
        Task {
            let actor = await RealmActor.shared()
            await actor.saveCollectionFilters(for: collectionId, filter: filter)
        }
    }
}

extension CollectionManagementView {
    func handleToggleFilterEnabled(_ value: Bool) {
        if presentationState != .loaded(true) {
            return
        }

        let id = collection.id

        Task {
            let actor = await RealmActor.shared()
            await actor.toggleCollectionFilters(id: id, value: value)
        }
    }

    func setTitlePinningType(_ value: TitlePinningType) {
        let id = collection.id
        if value != .none {
            pinningType = value
        }

        Task {
            let actor = await RealmActor.shared()
            await actor.setTitlePinningType(for: id, pinningType: value)
        }
    }
}
