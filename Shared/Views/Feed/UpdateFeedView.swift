//
//  FeedsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI
struct UpdateFeedView: View {
    @ObservedResults(LibraryEntry.self) var unfilteredEntries
    @State var selection: HighlightIndentier?

    var body: some View {
        let entries = filterEntries()
        let groups = groupEntries(entries)
        let sortedGroups = sortedTimeGroups(groups)
        List {
            ForEach(sortedGroups) {
                SectionGroup(key: $0, grouped: groups)
                    .id($0.hash)
            }
        }
        .refreshable {
            await handleRefresh()
        }
        .navigationTitle("Update Feed")
        .onAppear {
            STTNotifier.shared.clearBadge()
        }
        .listStyle(.plain)
        .animation(.default, value: unfilteredEntries)
        .modifier(InteractableContainer(selection: $selection))
    }

    @MainActor
    func handleRefresh() async {
        let count = await DaisukeEngine.shared.handleForegroundLibraryUpdate()
        if count == 0 {
            ToastManager.shared.setToast(toast: .init(type: .regular, title: "No Updates"))
        } else {
            ToastManager.shared.setToast(toast: .init(displayMode: .alert, type: .systemImage("bell.badge", .accentColor), title: "\(count) Updates Found"))
        }
    }

    func filterEntries() -> Results<LibraryEntry> {
        unfilteredEntries.where { entry in
            let timeAgo = Calendar.current.date(
                byAdding: .month,
                value: -5,
                to: Date()
            )!
            return entry.content != nil &&
                entry.updateCount > 0 &&
                entry.lastUpdated >= timeAgo
        }
        .sorted(by: \.lastUpdated, ascending: false)
    }

    typealias Grouped = [String: [LibraryEntry]]

    func groupEntries(_ entries: Results<LibraryEntry>) -> Grouped {
        return Dictionary(grouping: entries, by: { $0.lastUpdated.timeAgoGrouped() })
    }

    func sortedTimeGroups(_ groups: Grouped) -> [String] {
        return groups.keys.sorted(by: { groups[$0]![0].lastUpdated > groups[$1]![0].lastUpdated })
    }

    func SectionGroup(key: String, grouped: Grouped) -> some View {
        Section {
            ForEach(grouped[key]!) { entry in
                UpdateFeedTile(entry: entry)
                    .swipeActions(edge: .leading) {
                        Button(action: { DataManager.shared.clearUpdates(id: entry._id) }) {
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
            Text(key)
        }
        .headerProminence(.increased)
    }
}
