//
//  UpdateFeedView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI

struct UpdateFeedView: View {
    @State var selection: HighlightIdentifier?
    @StateObject var model = ViewModel()
    var body: some View {
        List {
            ForEach(model.data, id: \.header.hashValue) {
                SectionGroup(title: $0.header, entries: $0.content)
            }
        }
        .refreshable {
            await handleRefresh()
        }
        .navigationTitle("Update Feed")
        .task {
            STTNotifier.shared.clearBadge()
            await model.observe()
        }
        .onDisappear(perform: model.disconnect)
        .listStyle(.plain)
        .animation(.default, value: model.data)
        .modifier(InteractableContainer(selection: $selection))
    }

    func handleRefresh() async {
        let count = await DSK.shared.fetchLibraryUpdates()
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
                        Button(action: { clear(for: entry.id) }) {
                            Label("Clear Updates", systemImage: "xmark.circle")
                        }
                        .tint(.red)
                    }
                    .onTapGesture {
                        guard let content = entry.content else { return }
                        let highlight = content.toHighlight()
                        if content.streamable {
                            StateManager.shared.stream(item: highlight, sourceId: content.sourceId)
                        } else {
                            selection = nil
                            selection = (content.sourceId, nil, highlight)
                        }
                    }
                    .id(entry.hashValue)
            }
        } header: {
            Text(title)
        }
        .headerProminence(.increased)
    }

    func clear(for id: String) {
        Task {
            let actor = await RealmActor.shared()
            await actor.clearUpdates(id: id)
        }
    }
}

extension UpdateFeedView {
    final class ViewModel: ObservableObject {
        private var token: NotificationToken?
        @Published var data: [UpdateFeedGroup] = []
        func observe() async {
            let actor = await RealmActor.shared()
            token = await actor
                .observeUpdateFeed { feed in
                    Task { @MainActor [weak self] in
                        self?.data = feed
                    }
                }
        }

        func disconnect() {
            token?.invalidate()
            token = nil
        }
    }
}
