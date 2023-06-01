//
//  FeedsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI


struct UpdateFeedView: View {
    typealias Grouped = [String: [LibraryEntry]]
    @ObservedResults(LibraryEntry.self) var unfilteredEntries
    @State var selection: HighlightIndentier?
    @StateObject var model = ViewModel()
    var body: some View {
        List {
            if let data = model.data {
                ForEach(data, id: \.header.hashValue) {
                    SectionGroup(title: $0.header, entries: $0.content)
                }
            }
            
        }
        .refreshable {
            await handleRefresh()
        }
        .navigationTitle("Update Feed")
        .task {
            STTNotifier.shared.clearBadge()
            model.observe()
        }
        .onDisappear(perform: model.disconnect)
        .listStyle(.plain)
        .animation(.default, value: model.data)
        .modifier(InteractableContainer(selection: $selection))
    }

    @MainActor
    func handleRefresh() async {
        let count = await SourceManager.shared.handleForegroundLibraryUpdate()
        if count == 0 {
            ToastManager.shared.display(.info("No Updates in your library."))
        } else {
            ToastManager.shared.display(.info("\(count) Updates Found"))
        }
    }

    func SectionGroup(title: String, entries: [LibraryEntry]) -> some View {
        Section {
            ForEach(entries) { entry in
                UpdateFeedTile(entry: entry)
                    .swipeActions(allowsFullSwipe: true) {
                        Button(action: { DataManager.shared.clearUpdates(id: entry.id) }) {
                            Label("Clear Updates", systemImage: "xmark.circle")
                        }
                        .tint(.red)
                    }
                    .onTapGesture {
                        selection = nil
                        selection = (entry.content!.sourceId, entry.content!.toHighlight())
                    }
                    .id(entry.hashValue)
            }
        } header: {
            Text(title)
        }
        .headerProminence(.increased)
    }
}


extension UpdateFeedView {
    
    struct GroupedData : Hashable {
        var header: String
        var content: [LibraryEntry]
    }
    final class ViewModel: ObservableObject {
        private var token: NotificationToken?
        @Published var data : [GroupedData]?
        func observe() {
            let queue = DispatchQueue(label: "com.ceres.suwatte.feed")
            queue.async { [weak self] in
                let date = Calendar.current.date(byAdding: .month, value: -5, to: Date())!
                let realm = try! Realm()
                let library = realm
                    .objects(LibraryEntry.self)
                    .where({ $0.content != nil })
                    .where({ $0.updateCount > 0 })
                    .where({ $0.lastUpdated >= date })
                    .sorted(by: \.lastUpdated, ascending: false)

                self?.token = library
                    .observe(on: queue , {[weak self] _ in
                        let library = library.freeze()
                        self?.generate(entries: library)
                    })
            }
        }
        
        func generate(entries: Results<LibraryEntry>) {
            let grouped = Dictionary(grouping: entries, by: { $0.lastUpdated.timeAgoGrouped() })
            let sortedKeys = grouped.keys.sorted(by: { grouped[$0]![0].lastUpdated > grouped[$1]![0].lastUpdated })
            var prepared = [GroupedData]()
            sortedKeys.forEach {
                prepared.append(.init(header: $0, content: grouped[$0] ?? []))
            }
            
            let out = prepared
            Task { @MainActor in
                data = out
            }
        }
        
        func disconnect() {
            token?.invalidate()
            token = nil
        }
        
    }
    
}
