//
//  DV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import RealmSwift
import SwiftUI

// MARK: - View

struct ContentSourceDirectoryView: View {
    let source: JSCCS
    let request: DSKCommon.DirectoryRequest
    @State var selection: HighlightIdentifier?
    @StateObject var model = ViewModel()
    var body: some View {
        DirectoryView<DSKCommon.Highlight, Cell>(model: .init(runner: source, request: request)) { data in
            let inLibrary = model.library.contains(data.contentId)
            let inReadLater = model.readLater.contains(data.contentId)
            Cell(data: data, sourceID: source.id, inLibrary: inLibrary, readLater: inReadLater, selection: $selection)
        }
        .modifier(InteractableContainer(selection: $selection))
        .task {
            model.start(source.id)
        }
        .onDisappear(perform: model.stop)
    }
}

// MARK: - Cell

extension ContentSourceDirectoryView {
    struct Cell: View {
        var data: DSKCommon.Highlight
        var sourceID: String
        @State var inLibrary: Bool
        @State var readLater: Bool
        @Binding var selection: HighlightIdentifier?
        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: data, sourceId: sourceID)
                if inLibrary || readLater {
                    ColoredBadge(color: inLibrary ? .accentColor : .yellow)
                }
            }
            .onTapGesture {
                if data.canStream {
                    StateManager.shared.stream(item: data, sourceId: sourceID)
                } else {
                    selection = (sourceID, data)
                }
            }
            .contextMenu {
                Button {
                    Task {
                        let actor = await RealmActor()
                        await actor.toggleReadLater(sourceID, data.contentId)
                        await MainActor.run {
                            readLater.toggle()
                        }
                    }
                } label: {
                    Label(readLater ? "Remove from Read Later" : "Add to Read Later", systemImage: readLater ? "bookmark.slash" : "bookmark")
                }
            }
        }
    }
}

// MARK: - ViewModel

extension ContentSourceDirectoryView {
    final class ViewModel: ObservableObject {
        @Published var library: Set<String> = []
        @Published var readLater: Set<String> = []

        private var libraryToken: NotificationToken?
        private var rlToken: NotificationToken?

        func stop() {
            libraryToken?.invalidate()
            rlToken?.invalidate()
            libraryToken = nil
            rlToken = nil
        }

        func start(_ sourceID: String) {
            let realm = try! Realm()

            let library = realm
                .objects(LibraryEntry.self)
                .where { $0.isDeleted == false }
                .where { $0.content.sourceId == sourceID }

            libraryToken = library.observe { [weak self] _ in
                withAnimation {
                    self?.library = Set(library.compactMap(\.content?.contentId))
                }
            }

            // Read Later
            let readLater = realm
                .objects(ReadLater.self)
                .where { $0.isDeleted == false }
                .where { $0.content.sourceId == sourceID }

            rlToken = readLater.observe { [weak self] _ in
                withAnimation {
                    self?.readLater = Set(readLater.compactMap(\.content?.contentId))
                }
            }
        }
    }
}
