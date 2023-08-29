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
    let source: AnyContentSource
    let request: DSKCommon.DirectoryRequest
    @State var selection: HighlightIdentifier?
    @StateObject var model = ViewModel()
    var body: some View {
        DirectoryView<DSKCommon.Highlight, Cell>(model: .init(runner: source, request: request)) { data in
            let identifier = ContentIdentifier(contentId: data.contentId,
                                               sourceId: source.runnerID).id
            let inLibrary = model.library.contains(identifier)
            let inReadLater = model.readLater.contains(identifier)
            Cell(data: data,
                 sourceID: source.id,
                 inLibrary: inLibrary,
                 readLater: inReadLater,
                 selection: $selection)
        }
        .modifier(InteractableContainer(selection: $selection))
        .task {
            await model.start(source.id)
        }

        .onDisappear(perform: model.stop)
        .animation(.default, value: model.readLater)
        .animation(.default, value: model.library)
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
            DefaultTile(entry: data, sourceId: sourceID)
                .coloredBadge(inLibrary ? .accentColor : readLater ? .yellow : nil)
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
                            let actor = await RealmActor.shared()
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

        func start(_ sourceID: String) async {
            let actor = await RealmActor.shared()

            libraryToken = await actor
                .observeLibraryIDs(sourceID: sourceID) { [weak self] values in
                    self?.library = values
                }

            rlToken = await actor
                .observeReadLaterIDs(sourceID: sourceID) { [weak self] values in
                    self?.readLater = values
                }
        }
    }
}
