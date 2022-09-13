//
//  LibraryGrid+GridView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-24.
//

import ASCollectionView
import RealmSwift
import SwiftUI

extension LibraryView.LibraryGrid {
    struct Grid: View {
        var entries: Results<LibraryEntry>
        var collection: LibraryCollection?
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @EnvironmentObject var model: LibraryView.LibraryGrid.ViewModel
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @State private var isPotrait = KEY_WINDOW?.windowScene?.interfaceOrientation == .portrait

        var body: some View {
            ASCollectionView(editMode: model.isSelecting) {
                ASCollectionViewSection(id: 0,
                                        data: entries,
                                        selectionMode: model.isSelecting ? .selectMultiple($model.selectedIndexes) : .none,
                                        contextMenuProvider: contextMenuProvider) { entry, state in

                    ZStack(alignment: .topTrailing) {
                        Button {
                            model.navSelection = entry
                        } label: {
                            LibraryView.LibraryGrid.GridTile(entry: entry)
                        }
                        .buttonStyle(NeutralButtonStyle())
                        .disabled(model.isSelecting)

                        Image(systemName: "circle.fill")
                            .resizable()
                            .foregroundColor(state.isSelected ? .accentColor : .black)
                            .clipShape(Circle())
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(Color.white, lineWidth: 3).shadow(radius: 10))
                            .padding(.all, 5)
                            .opacity(model.isSelecting ? 1 : 0)
                    }
                    .animation(.default, value: model.isSelecting)
                    .animation(.default, value: model.selectedIndexes)
                }
                .sectionHeader(content: {
                    EmptyView()
                })
                .sectionFooter(content: {
                    EmptyView()
                })
            }
            .layout(createCustomLayout: {
                SuwatteDefaultGridLayout(itemsPerRow: itemsPerRow, style: style)
            }, configureCustomLayout: { layout in
                layout.itemsPerRow = itemsPerRow
                layout.itemStyle = style
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .onRotate { newOrientation in

                if newOrientation.isFlat { return }
                isPotrait = newOrientation.isPortrait
            }
            .animation(.default, value: model.isSelecting)
            .animation(.default, value: model.selectedIndexes)
        }

        var itemsPerRow: Int {
            isPotrait ? PortraitPerRow : LSPerRow
        }

        func contextMenuProvider(int _: Int, content: LibraryEntry) -> UIContextMenuConfiguration? {
            let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil)
                { _ -> UIMenu? in

                    var nonDestructiveActions = [UIAction]()
                    var destructiveActions: [UIAction] = []

                    if let url = URL(string: content.content?.webUrl ?? "") {
                        // Share
                        let shareAction = UIAction(title: "Share", image: .init(systemName: "square.and.arrow.up"))
                            { _ in
                                let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                                KEY_WINDOW?.rootViewController?.present(av, animated: true)
                            }

                        nonDestructiveActions.append(shareAction)
                    }

                    // Edit Categories
                    if let content = content.content?.thaw() {
                        let editCollectionsAction = UIAction(title: "Manage", image: .init(systemName: "gearshape"))
                            { _ in
                                //
                                let controller = UIHostingController(rootView: ProfileView.Sheets.LibrarySheet().environmentObject(content))
                                KEY_WINDOW?.rootViewController?.present(controller, animated: true)
                            }

                        nonDestructiveActions.append(editCollectionsAction)
                    }

                    // Clear Upates
                    if content.updateCount >= 1 {
                        let clearUpdatesActions = UIAction(title: "Clear Updates", image: UIImage(systemName: "bell.slash"), attributes: .destructive) {
                            _ in
                            DataManager.shared.clearUpdates(id: content._id)
                        }

                        destructiveActions.append(clearUpdatesActions)
                    }

                    // Remove from Collection
                    if let collection = collection {
                        let removeFromCollection = UIAction(title: "Remove from Collection", image: .init(systemName: "xmark"), attributes: .destructive)
                            { _ in
                                //
                                DataManager.shared.toggleCollection(for: content, withId: collection._id)
                            }

                        destructiveActions.append(removeFromCollection)
                    }

                    // Remove from Library
                    if let content = content.content {
                        let removeFromLibAction = UIAction(title: "Remove from library", image: .init(systemName: "trash"), attributes: .destructive)
                            { _ in
                                DataManager.shared.toggleLibraryState(for: content)
                            }
                        destructiveActions.append(removeFromLibAction)
                    }

                    let nonDestructiveMenu = UIMenu(title: "", options: .displayInline, children: nonDestructiveActions)

                    let destructiveMenu = UIMenu(title: "", options: .displayInline, children: destructiveActions)

                    return UIMenu(title: "Options", image: nil, identifier: nil, options: [], children: [nonDestructiveMenu, destructiveMenu])
                }
            return configuration
        }
    }
}

// https://stackoverflow.com/a/62311089
struct NeutralButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

class SuwatteDefaultGridLayout: UICollectionViewFlowLayout {
    var itemsPerRow: Int {
        didSet {
            invalidateLayout()
        }
    }

    var itemStyle: TileStyle {
        didSet {
            invalidateLayout()
        }
    }

    var titleSize = CGFloat(50)
    init(itemsPerRow: Int, style: TileStyle) {
        self.itemsPerRow = itemsPerRow
        itemStyle = style
        super.init()

        minimumInteritemSpacing = 6
        minimumLineSpacing = 6
        sectionInset = .init(top: 15, left: 20, bottom: 10, right: 20)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }

        collectionView.allowsMultipleSelectionDuringEditing = true
        let itemSpacing = minimumInteritemSpacing * CGFloat(itemsPerRow - 1)
        let sectionInsets = sectionInset.left + sectionInset.right
        let insets = collectionView.safeAreaInsets
        let safeAreaInsets = insets.right + insets.left
        let total = itemSpacing + sectionInsets + safeAreaInsets
        let width = collectionView.bounds.width - total

        let itemWidth = (width / CGFloat(itemsPerRow)).rounded(.down)

        var itemHeight = itemWidth * 1.5
        if itemStyle == .SEPARATED, itemWidth >= 100 {
            itemHeight += titleSize
        }

        itemSize = CGSize(width: itemWidth, height: itemHeight)
    }
}
