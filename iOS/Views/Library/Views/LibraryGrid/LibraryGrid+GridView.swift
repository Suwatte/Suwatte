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
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @EnvironmentObject var model: LibraryView.LibraryGrid.ViewModel
        @State var manageSelection: String?

        var regularLibrary: [LibraryEntry] {
            model.regularLibrary ?? []
        }

        var pinnedLibrary: [LibraryEntry] {
            model.pinnedLibrary ?? []
        }

        func getCell(_ entry: LibraryEntry, _ state: ASCellContext) -> some View {
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
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3).shadow(radius: 10))
                    .padding(.all, 5)
                    .opacity(model.isSelecting ? 1 : 0)
            }
            .animation(.default, value: model.isSelecting)
            .animation(.default, value: model.selectedPinnedIndexes)
            .animation(.default, value: model.selectedRegularIndexes)
        }

        func getPinnedSection() -> ASCollectionViewSection<Int> {
            ASCollectionViewSection(id: 0,
                                    data: pinnedLibrary,
                                    selectionMode: model.isSelecting ? .selectMultiple($model.selectedPinnedIndexes) : .none,
                                    contextMenuProvider: contextMenuProvider)
            { entry, state in
                getCell(entry, state)
            }
            .sectionHeader {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.footnote)
                        .rotationEffect(Angle(degrees: -30))
                        .foregroundColor(.accentColor)
                    Text("^[\(pinnedLibrary.count) Title](inflect: true)")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .sectionFooter {
                EmptyView()
            }
        }

        func getRegularSection() -> ASCollectionViewSection<Int> {
            ASCollectionViewSection(id: 1,
                                    data: regularLibrary,
                                    selectionMode: model.isSelecting ? .selectMultiple($model.selectedRegularIndexes) : .none,
                                    contextMenuProvider: contextMenuProvider)
            { entry, state in
                getCell(entry, state)
            }
            .sectionHeader {
                HStack {
                    Text("^[\(regularLibrary.count) Title](inflect: true)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .sectionFooter {
                EmptyView()
            }
        }

        var body: some View {
            ASCollectionView(editMode: model.isSelecting) {
                if !pinnedLibrary.isEmpty {
                    getPinnedSection()
                }
                if !regularLibrary.isEmpty {
                    getRegularSection()
                }
            }
            .layout {
                DynamicGridLayout(header: .absolute(22))
            }
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .shouldInvalidateLayoutOnStateChange(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            .animation(.default, value: model.isSelecting)
            .animation(.default, value: model.selectedPinnedIndexes)
            .animation(.default, value: model.selectedRegularIndexes)
            .sheet(item: $manageSelection) { selection in
                ProfileView.Sheets.LibrarySheet(id: selection)
                    .environmentObject(StateManager.shared)
            }
        }

        func contextMenuProvider(int _: Int, content: LibraryEntry) -> UIContextMenuConfiguration? {
            let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ -> UIMenu? in
                var nonDestructiveActions = [UIAction]()
                var destructiveActions: [UIAction] = []

                if let url = URL(string: content.content?.webUrl ?? "") {
                    // Share
                    let shareAction = UIAction(title: "Share", image: .init(systemName: "square.and.arrow.up")) { _ in
                        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        let window = getKeyWindow()
                        window?.rootViewController?.present(av, animated: true)
                    }

                    nonDestructiveActions.append(shareAction)
                }

                // Edit Categories
                if let id = content.content?.id {
                    let editCollectionsAction = UIAction(title: "Manage", image: .init(systemName: "gearshape")) { _ in
                        //
                        manageSelection = id
                    }

                    nonDestructiveActions.append(editCollectionsAction)
                }

                // Clear Upates
                if content.updateCount >= 1 {
                    let clearUpdatesActions = UIAction(title: "Clear Updates", image: UIImage(systemName: "bell.slash"), attributes: .destructive) {
                        _ in
                        let id = content.id
                        Task {
                            let actor = await Suwatte.RealmActor.shared()
                            await actor.clearUpdates(id: id)
                        }
                    }

                    destructiveActions.append(clearUpdatesActions)
                }

                // Remove from Collection
                if let collection = model.collection {
                    let removeFromCollection = UIAction(title: "Remove from Collection", image: .init(systemName: "xmark"), attributes: .destructive) { _ in
                        //
                        let contentId = content.id
                        let collectionID = collection.id
                        Task {
                            let actor = await Suwatte.RealmActor.shared()
                            await actor.toggleCollection(for: contentId, withId: collectionID)
                        }
                    }

                    destructiveActions.append(removeFromCollection)
                }

                // Remove from Library
                if let content = content.content {
                    let removeFromLibAction = UIAction(title: "Remove from library", image: .init(systemName: "trash"), attributes: .destructive) { _ in
                        let cID = content.ContentIdentifier
                        Task {
                            let actor = await Suwatte.RealmActor.shared()
                            await actor.toggleLibraryState(for: cID)
                        }
                    }
                    destructiveActions.append(removeFromLibAction)
                }

                let nonDestructiveMenu = UIMenu(title: "", options: .displayInline, children: nonDestructiveActions)

                let destructiveMenu = UIMenu(title: "", options: .displayInline, children: destructiveActions)

                return UIMenu(title: content.content?.title ?? "Options", image: nil, identifier: nil, options: [], children: [nonDestructiveMenu, destructiveMenu])
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

@MainActor
func DynamicGridLayout(header: NSCollectionLayoutDimension? = nil, footer: NSCollectionLayoutDimension? = nil, _ titleSize: CGFloat? = nil) -> UICollectionViewCompositionalLayout {
    UICollectionViewCompositionalLayout { _, environment in
        let viewingPortrait = environment.container.contentSize.width < environment.container.contentSize.height
        let itemsPerRow = UserDefaults.standard.integer(forKey: viewingPortrait ? STTKeys.GridItemsPerRow_P : STTKeys.GridItemsPerRow_LS)
        let style = TileStyle(rawValue: UserDefaults.standard.integer(forKey: STTKeys.TileStyle)) ?? .COMPACT

        let SPACING: CGFloat = 8.5
        let INSET: CGFloat = 16
        let totalSpacing = SPACING * CGFloat(itemsPerRow - 1)
        let groupWidth = environment.container.contentSize.width - (INSET * 2) - totalSpacing
        let estimatedItemWidth = (groupWidth / CGFloat(itemsPerRow)).rounded(.down)
        let shouldAddTitle = style == .SEPARATED && estimatedItemWidth >= 100 || titleSize != nil
        let titleSize: CGFloat = shouldAddTitle ? titleSize ?? 48 : 0
        let height = (estimatedItemWidth * 1.5) + titleSize

        // Item
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / CGFloat(itemsPerRow)),
            heightDimension: .absolute(height)
        ))

        // Group / Row
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(height)
            ),
            subitem: item,
            count: itemsPerRow
        )
        group.interItemSpacing = .fixed(SPACING)
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 10, leading: INSET, bottom: 20, trailing: INSET)
        section.interGroupSpacing = SPACING

        var items: [NSCollectionLayoutBoundarySupplementaryItem] = []

        if let header {
            let headerComponent: NSCollectionLayoutBoundarySupplementaryItem = .init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: header), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            items.append(headerComponent)
        }

        if let footer {
            let footerComponent: NSCollectionLayoutBoundarySupplementaryItem = .init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: footer), elementKind: UICollectionView.elementKindSectionFooter, alignment: .bottom)
            items.append(footerComponent)
        }
        section.boundarySupplementaryItems = items
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }
}
