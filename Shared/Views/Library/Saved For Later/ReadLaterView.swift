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
        typealias Highlight = DaisukeEngine.Structs.Highlight
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @StateObject var model = ViewModel()
        var body: some View {
            Group {
                if let readLater = model.readLater {
                    ASCollectionView {
                        ASCollectionViewSection(id: 0,
                                                data: readLater,
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
                        DynamicGridLayout()
                    }, configureCustomLayout: { layout in
                        layout.invalidateLayout()
                    })
                    .alwaysBounceVertical()
                    .animateOnDataRefresh(true)
                    .ignoresSafeArea(.keyboard, edges: .all)
                } else {
                    ProgressView()

                }
            }
            .animation(.default, value: model.library)
            .animation(.default, value: model.readLater)
            .navigationTitle("Saved For Later")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                model.observe()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort Titles", selection: $model.sort) {
                            ForEach(ContentSort.allCases, id: \.rawValue) { val in
                                Text(val.description)
                                .tag(val)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Order Titles", selection: $model.ascending) {
                           Text("Ascending")
                            .tag(true)
                            Text("Descending")
                            .tag(false)
                        }
                        .pickerStyle(.menu)
                        Divider()
                        Button {
                            model.refresh()
                        } label: {
                            Label("Refresh Database", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Titles")
            .animation(.default, value: model.query)
        }
    }
}

extension LibraryView.ReadLaterView {
    func inLibrary(_ entry: ReadLater) -> Bool {
        guard let library = model.library else {
            return false
        }
        return library
            .contains(where: { $0.id == entry.id })
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
