//
//  DV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI
import RealmSwift

// MARK: -View
struct ContentSourceDirectoryView: View {
    let source: JSCCS
    let request: DSKCommon.DirectoryRequest
    @State var selection: HighlightIndentier?
    @StateObject var model = ViewModel()
    var body: some View {
        DirectoryView<DSKCommon.Highlight, Cell>(model: .init(runner: source, request: request), fullSearch: fullSearch) { data in
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
    
    var fullSearch: Bool {
        request.custom == nil && request.tag == nil
    }
}

// MARK: - Cell
extension ContentSourceDirectoryView {
    struct Cell: View {
        var data: DSKCommon.Highlight
        var sourceID: String
        @State var inLibrary: Bool
        @State var readLater: Bool
        @Binding var selection: HighlightIndentier?
        var body: some View {
            ZStack(alignment: .topTrailing) {
                DefaultTile(entry: data, sourceId: sourceID)
                if inLibrary || readLater {
                    ColoredBadge(color: inLibrary ? .accentColor : .yellow)
                }
            }
            .onTapGesture {
                selection = (sourceID, data)
            }
            .contextMenu {
                Button {
                    if readLater {
                        DataManager.shared.removeFromReadLater(sourceID, content: data.contentId)
                    } else {
                        DataManager.shared.addToReadLater(sourceID, data.contentId)
                    }
                    readLater.toggle()
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
