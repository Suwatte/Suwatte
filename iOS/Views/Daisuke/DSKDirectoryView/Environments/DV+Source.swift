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
    
    @StateObject var manager = LocalAuthManager.shared
    @Preference(\.protectContent) var protectContent
    
    var body: some View {
        DirectoryView(model: .init(runner: source, request: request)) { data in
            let identifier = ContentIdentifier(contentId: data.id,
                                               sourceId: source.id).id
            let inLibrary = model.library.contains(identifier)
            let inReadLater = model.readLater.contains(identifier)
           
            DSKHighlightTile(data: data,
                             source: source,
                             inLibrary: inLibrary,
                             inReadLater: inReadLater,
                             selection: $selection,
                             hideLibraryBadges: hideLibrayBadges)
        }
        .modifier(InteractableContainer(selection: $selection))
        .task {
            await model.start(source.id)
        }

        .onDisappear(perform: model.stop)
        .animation(.default, value: model.readLater)
        .animation(.default, value: model.library)
    }
    
    private var hideLibrayBadges: Bool {
        protectContent && manager.isExpired
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
