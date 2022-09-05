//
//  ReadLaterView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//

import ASCollectionView
import RealmSwift
import SwiftUI

extension LibraryView {
    struct ReadLaterView: View {
        @ObservedResults(ReadLater.self, where: { $0.content != nil }) var unsortedEntries
        @State var ascending = false
        @State var option = ContentSort.dateAdded
        @State var text = ""
        typealias Highlight = DaisukeEngine.Structs.Highlight

        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        @ObservedResults(LibraryEntry.self) var library

        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6

        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait

        var body: some View {
            let entries = sortedEntries()

            ASCollectionView {
                ASCollectionViewSection(id: 0,
                                        data: entries,
                                        contextMenuProvider: contextMenuProvider) { data, _ in
                    let isInLibrary = inLibrary(data)
                    let highlight = data.content!.toHighlight()
                    NavigationLink {
                        ProfileView(entry: highlight, sourceId: data.content!.sourceId)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            DefaultTile(entry: highlight)

                            if isInLibrary {
                                ColoredBadge(color: .accentColor)
                            }
                        }
                    }
                    .buttonStyle(NeutralButtonStyle())
                }
                .sectionHeader {
                    EmptyView()
                }
                .sectionFooter {
                    EmptyView()
                }
            }

            .layout(createCustomLayout: {
                SuwatteDefaultGridLayout(itemsPerRow: itemsPerRow, style: style)
            }, configureCustomLayout: { layout in
                layout.itemsPerRow = itemsPerRow
                layout.itemStyle = style
            })
            .alwaysBounceVertical()
            .onRotate { newOrientation in
                if newOrientation.isFlat { return }
                isPotrait = newOrientation.isPortrait
            }
            .animation(.default, value: library)
            .animation(.default, value: unsortedEntries)
            .navigationTitle("Saved For Later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort Titles", selection: $option) {
                            ForEach(ContentSort.allCases, id: \.rawValue) { val in
                                Button(val.description) {
                                    option = val
                                }
                                .tag(val)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Order Titles", selection: $ascending) {
                            Button("Ascending") {
                                ascending = true
                            }
                            .tag(true)
                            Button("Descending") {
                                ascending = false
                            }
                            .tag(false)
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $text, collection: $unsortedEntries, keyPath: \.content!.title, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Titles")
            .animation(.default, value: text)
        }

        func sortedEntries() -> Results<ReadLater> {
            return unsortedEntries.sorted(byKeyPath: option.KeyPath, ascending: ascending)
        }
    }
}

extension LibraryView.ReadLaterView {
    func inLibrary(_ entry: ReadLater) -> Bool {
        library
            .contains(where: { $0._id == entry._id })
    }

    func contextMenuProvider(int _: Int, entry: ReadLater) -> UIContextMenuConfiguration? {
        guard let content = entry.content?.thaw() else {
            return nil
        }
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil)
            { _ -> UIMenu? in

                var actions = [UIAction]()
                let removeAction = UIAction(title: "Remove from Read Later", image: UIImage(systemName: "bookmark.slash"), attributes: .destructive) {
                    _ in
                    DataManager.shared.removeFromReadLater(content.sourceId, content: content.contentId)
                }
                actions.append(removeAction)

                if !inLibrary(entry) {
                    let moveAction = UIAction(title: "Move to Library", image: UIImage(systemName: "folder")) {
                        _ in

                        DataManager.shared.removeFromReadLater(content.sourceId, content: content.contentId)
                        DataManager.shared.toggleLibraryState(for: content)
                    }
                    actions.append(moveAction)
                }

                return .init(title: "", children: actions)
            }
        return configuration
    }
}

extension LibraryView.ReadLaterView {
    enum ContentSort: Int, CaseIterable {
        case dateAdded, title

        var description: String {
            switch self {
            case .dateAdded:
                return "Date Added"
            case .title:
                return "Title"
            }
        }

        var KeyPath: String {
            switch self {
            case .dateAdded:
                return "dateAdded"
            case .title:
                return "content.title"
            }
        }
    }
}
