//
//  MigrationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-22.
//

import RealmSwift
import SwiftUI

struct MigrationView: View {
    @State var contents: [StoredContent]
    @State var libraryStrat = LibraryStrategy.replace
    @State var notFoundStrat = NotFoundStrategy.skip
    @State var lessChapterSrat = LowerChapterStrategy.skip
    @State var operationState = OperationState.idle
    @State var operations: [String: ItemState] = [:]
    @State var operationsTask: Task<Void, Never>?
    @State var preferredDestinations: [AnyContentSource] = []
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
    @Environment(\.presentationMode) var presentationMode
    @State var presentAlert = false
    @ObservedResults(StoredRunnerObject.self, where: { $0.isDeleted == false && $0.enabled == true }) var runners
    var body: some View {
        List {
            Section {
                STTLabelView(title: "Title Count", label: contents.count.description)
                STTLabelView(title: "State", label: operationState.description)
            }
            switch operationState {
            case .idle: SettingsSection
            case .searching:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            case .searchComplete: MigrationSection
            case .migrationComplete: Text("Done!").foregroundColor(.green)
            }

            EntriesView
        }
        .navigationTitle("Migrate")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: cancelOperations)
        .animation(.default, value: operationState)

        .alert("Start Migration", isPresented: $presentAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Start", role: .destructive) {
                migrate(data: operations)
            }
        } message: {
            Text("Are you sure you want to begin the migration?\nA backup will be automatically generated to protect your data.")
        }
    }
}

extension MigrationView {
    var CAN_START: Bool {
        !preferredDestinations.isEmpty
    }
}

// MARK: Strategy

extension MigrationView {
    enum LibraryStrategy: CaseIterable {
        case link, replace

        var description: String {
            switch self {
            case .link: return "Link"
            case .replace: return "Replace"
            }
        }
    }

    enum NotFoundStrategy: CaseIterable {
        case remove, skip
        var description: String {
            switch self {
            case .remove: return "Remove"
            case .skip: return "Skip"
            }
        }
    }

    enum LowerChapterStrategy: CaseIterable {
        case skip, migrate

        var description: String {
            switch self {
            case .migrate: return "Migrate Anyway"
            case .skip: return "Skip"
            }
        }
    }
}

// MARK: States

extension MigrationView {
    enum OperationState {
        case idle, searching, searchComplete, migrationComplete

        var description: String {
            switch self {
            case .idle: return "Idle"
            case .searching: return "Searching"
            case .searchComplete: return "Pre-Migration"
            case .migrationComplete: return "Done!"
            }
        }
    }

    enum ItemState: Equatable {
        case idle, searching, found(_ entry: HighlightIndentier), noMatches, lowerFind(_ entry: HighlightIndentier, _ initial: Double, _ next: Double)

        static func == (lhs: ItemState, rhs: ItemState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.found, .found), (.noMatches, .noMatches), (.lowerFind, .lowerFind): return true
            default: return false
            }
        }

        func value() -> HighlightIndentier? {
            switch self {
            case .searching, .idle, .noMatches: return nil
            case let .found(entry), let .lowerFind(entry, _, _):
                return entry
            }
        }
    }
}

// MARK: Settings Section

extension MigrationView {
    var SettingsSection: some View {
        Section {
            NavigationLink {
                PreferredDestinationsView
            } label: {
                STTLabelView(title: "Preferred Destinations", label: DestinationsLabel())
            }

            Button { startOperations() } label: {
                Label("Begin Searches", systemImage: "magnifyingglass")
            }
            .disabled(!CAN_START)
        } header: {
            Text("Setup")
        }
        .buttonStyle(.plain)
    }

    func DestinationsLabel() -> String {
        var label = "No Selections"
        let count = preferredDestinations.count
        if count == 1 {
            label = preferredDestinations.first?.name ?? ""
        } else if count != 0 {
            label = "\(count) Sources"
        }
        return label
    }
}

// MARK: Info Views

extension MigrationView {
    var InfoView: some View {
        List {
            Section {}
        }
    }

    var PreferredDestinationsView: some View {
        List {
            Section {
                ForEach(preferredDestinations, id: \.id) { source in
                    Text(source.name)
                        .onTapGesture {
                            preferredDestinations.removeAll(where: { $0.id == source.id })
                        }
                }
                .onMove(perform: move)
            } header: {
                Text("Destinations")
            }

            Section {
                ForEach(getAvailableSources(), id: \.id) { source in
                    Text(source.name)
                        .onTapGesture {
                            preferredDestinations.append(source)
                        }
                }
            } header: {
                Text("Available")
            }
        }
        .navigationTitle("Sources")
        .environment(\.editMode, .constant(.active))
    }

    private func getAvailableSources() -> [AnyContentSource] {
        let allSources = SourceManager.shared.sources.values
        return allSources
            .filter { !preferredDestinations.map(\.id).contains($0.id) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        preferredDestinations.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: Functions

extension MigrationView {
    func startOperations() {
        operationsTask = Task {
            await start()
        }
    }

    func cancelOperations() {
        operationsTask?.cancel()
        operationsTask = nil
    }

    func removeItem(id: String) {
        contents.removeAll(where: { $0.id == id })
        operations.removeValue(forKey: id)
    }
}

// MARK: Entries View

extension MigrationView {
    @ViewBuilder
    var EntriesView: some View {
        let sorted = contents.sorted(by: \.title, descending: false)
        ForEach(sorted) { content in
            let state = operations[content.id] ?? .idle
            Section {
                ItemCell(content, state)
            } header: {
                if content.id == sorted.first?.id {
                    Text("Titles")
                }
            }
            .headerProminence(.increased)
        }
    }
}

// MARK: Item Cell

extension MigrationView {
    @ViewBuilder
    func ItemCell(_ content: StoredContent, _ state: ItemState) -> some View {
        let name = runners.where({ $0.id == content.sourceId }).first?.name ?? ""
        VStack {
            // Warning
            HStack {
                Text(content.SourceName)
                Spacer()
                Text(name)
            }
            .padding(.horizontal)
            .font(.subheadline.weight(.ultraLight))
            HStack(alignment: .center) {
                Spacer()
                DefaultTile(entry: content.toHighlight(), sourceId: content.sourceId)
                    .frame(width: CELL_WIDTH)
                Image(systemName: "chevron.right.circle")
                    .frame(height: CELL_WIDTH * 1.5)
                    .foregroundColor(ChevronColor(state))
                ItemCellResult(state, content)
                Spacer()
            }
            .frame(height: CELL_HEIGHT)
        }
        .swipeActions {
            Button(role: .destructive) {
                removeItem(id: content.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private var CELL_HEIGHT: CGFloat {
        (CELL_WIDTH * 1.5) + (tileStyle.titleHeight)
    }

    private var CELL_WIDTH: CGFloat {
        150
    }

    private func ChevronColor(_ state: ItemState) -> Color {
        switch state {
        case .idle: return .gray
        case .searching: return .blue
        case .lowerFind: return .yellow
        case .noMatches: return .red
        case .found: return .green
        }
    }

    @ViewBuilder
    private func ItemCellResult(_ state: ItemState, _ initial: StoredContent) -> some View {
        Group {
            switch state {
            case .idle, .searching:
                DefaultTile(entry: DSKCommon.Highlight.placeholders().first!)
                    .redacted(reason: .placeholder)
            case .noMatches:
                NavigationLink {
                    ManualDestinationSelectionView(content: initial, states: $operations)
                } label: {
                    VStack(alignment: .center) {
                        Text("No Matches")
                        Text("Tap To Manually Find")
                            .font(.callout)
                            .fontWeight(.light)
                            .multilineTextAlignment(.center)
                    }
                }
            case let .found(entry), let .lowerFind(entry, _, _):
                DefaultTile(entry: entry.entry, sourceId: entry.sourceId)
            }
        }
        .frame(width: CELL_WIDTH)
    }
}

// MARK: Find Matches

extension MigrationView {
    func start() async {
        await MainActor.run(body: {
            operationState = .searching
        })

        for content in contents {
            let id = content.id
//            await MainActor.run(body: {
//                operations[id] = .searching
//            })
            let lastChapter = DataManager.shared.getLatestStoredChapter(content.sourceId, content.contentId)?.number
            let sources = preferredDestinations.filter { $0.id != content.sourceId }
            if Task.isCancelled {
                return
            }
            // Get Content & Chapters
            let result = await handleSourcesSearch(id: content.id, query: content.title, chapter: lastChapter, sources: sources)

            Task { @MainActor in
                withAnimation {
                    operations[result.0] = result.1
                }
            }
        }

        await MainActor.run(body: {
            operationState = .searchComplete
        })
    }

    private typealias ReturnValue = (HighlightIndentier, Double)
    private func handleSourcesSearch(id: String, query: String, chapter: Double?, sources: [AnyContentSource]) async -> (String, ItemState) {
        await withTaskGroup(of: ReturnValue?.self, body: { group in

            for source in sources {
                group.addTask {
                    await searchSource(query: query, chapter: chapter, source: source)
                }
            }

            var max: ReturnValue?
            for await value in group {
                if let value {
                    // Chapter matches
                    let currentChapterNumber = max?.1 ?? 0
                    let matches = value.1 >= currentChapterNumber

                    if matches {
                        if let cId = max?.0.sourceId {
                            let index = sources.firstIndex(where: { $0.id == value.0.sourceId }) ?? Int.max
                            let currentIndex = sources.firstIndex(where: { $0.id == cId }) ?? Int.max

                            if index < currentIndex {
                                max = value
                            }
                        } else {
                            if currentChapterNumber < value.1 {
                                max = value
                            }
                        }
                    }
                }
            }

            if let max {
                if max.1 >= (chapter ?? 0) {
                    return (id, .found(max.0))
                } else {
                    return (id, .lowerFind(max.0, chapter ?? 0, max.1))
                }
            } else {
                return (id, .noMatches)
            }
        })
    }

    private func searchSource(query: String, chapter: Double?, source: AnyContentSource) async -> ReturnValue? {
        let data = try? await source.getSearchResults(.init(query: query))
        let result = data?.results.first

        guard let result else { return nil }
        let content = try? await source.getContent(id: result.contentId)
        guard let content else { return nil }

        var chapters = content.chapters

        if chapters == nil {
            chapters = await getChapters(for: source, id: content.contentId)
        }

        let target = chapters?.first

        guard let target, let chapter, target.number >= chapter else { return nil }

        let identifier: HighlightIndentier = (source.id, result)
        return (identifier, target.number)
    }

    private func getChapters(for source: AnyContentSource, id: String) async -> [DSKCommon.Chapter] {
        (try? await source.getContentChapters(contentId: id)) ?? []
    }
}

extension MigrationView {
    var MigrationSection: some View {
        Section {
            Picker("Migration Strategy", selection: $libraryStrat) {
                ForEach(LibraryStrategy.allCases, id: \.hashValue) {
                    Text($0.description)
                        .tag($0)
                }
            }

            Picker("On Replacement with Less Chapters", selection: $lessChapterSrat) {
                ForEach(LowerChapterStrategy.allCases, id: \.hashValue) {
                    Text($0.description)
                        .tag($0)
                }
            }
            Picker("On Replacement Not Found", selection: $notFoundStrat) {
                ForEach(NotFoundStrategy.allCases, id: \.hashValue) {
                    Text($0.description)
                        .tag($0)
                }
            }

            Button { filterNonMatches() } label: {
                Label("Filter Out Non-Matches", systemImage: "line.3.horizontal.decrease.circle")
            }
            Button { presentAlert.toggle() } label: {
                Label("Start Migration", systemImage: "shippingbox")
            }
        } header: {
            Text("Pre-Migration")
        }
        .buttonStyle(.plain)
        .disabled(contents.isEmpty)
    }

    private func filterNonMatches() {
        let cases = contents.filter { content in
            let data = operations[content.id]
            guard let data else { return true }
            switch data {
            case .found: return false
            default: return true
            }
        }.map(\.id)

        contents.removeAll(where: { cases.contains($0.id) })
        cases.forEach {
            operations.removeValue(forKey: $0)
        }
    }

    func migrate(data: [String: ItemState]) {
        ToastManager.shared.loading = true
        ToastManager.shared.info("Migration In Progress\nYour Data has been backed up.")
        try! BackupManager.shared.save(name: "PreMigration")
        let realm = try! Realm()

        func doMigration(entry: HighlightIndentier, target: LibraryEntry) {
            var stored = realm
                .objects(StoredContent.self)
                .where { $0.contentId == entry.entry.contentId }
                .where { $0.sourceId == entry.sourceId }
                .first

            stored = stored ?? entry.entry.toStored(sourceId: entry.sourceId)
            guard let stored else { return }

            switch libraryStrat {
            case .link:
                guard let content = target.content else { return }
                _ = DataManager.shared.linkContent(stored.id, content.id)
            case .replace:
                let obj = LibraryEntry()
                obj.content = stored
                obj.collections = target.collections
                obj.flag = target.flag
                obj.dateAdded = target.dateAdded
                realm.add(obj)
                realm.delete(target)
            }
        }
        try! realm.safeWrite {
            for (id, state) in data {
                let target = realm
                    .objects(LibraryEntry.self)
                    .where { $0.id == id }
                    .first
                guard let target else { continue }
                switch state {
                case let .found(entry):
                    doMigration(entry: entry, target: target)
                case let .lowerFind(entry, _, _):
                    if lessChapterSrat == .skip { continue }
                    doMigration(entry: entry, target: target)
                default:
                    if notFoundStrat == .remove {
                        realm.delete(target)
                    }
                }
            }
        }
        ToastManager.shared.loading = false
        ToastManager.shared.cancel()
        ToastManager.shared.info("Migration Complete!")
        presentationMode.wrappedValue.dismiss()
    }
}
