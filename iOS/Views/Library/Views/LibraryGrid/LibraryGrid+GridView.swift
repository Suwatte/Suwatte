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

        var body: some View {
            ASCollectionView(editMode: model.isSelecting) {
                ASCollectionViewSection(id: 0,
                                        data: entries,
                                        selectionMode: model.isSelecting ? .selectMultiple($model.selectedIndexes) : .none,
                                        contextMenuProvider: contextMenuProvider)
                { entry, state in

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
                DynamicGridLayout()
            }, configureCustomLayout: { layout in
                layout.invalidateLayout()
            })
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .ignoresSafeArea(.keyboard, edges: .all)
            .animation(.default, value: model.isSelecting)
            .animation(.default, value: model.selectedIndexes)
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
                                let controller = UIHostingController(rootView: ProfileView.Sheets.LibrarySheet(storedContent: content))
                                KEY_WINDOW?.rootViewController?.present(controller, animated: true)
                            }

                        nonDestructiveActions.append(editCollectionsAction)
                    }

                    // Clear Upates
                    if content.updateCount >= 1 {
                        let clearUpdatesActions = UIAction(title: "Clear Updates", image: UIImage(systemName: "bell.slash"), attributes: .destructive) {
                            _ in
                            DataManager.shared.clearUpdates(id: content.id)
                        }

                        destructiveActions.append(clearUpdatesActions)
                    }

                    // Remove from Collection
                    if let collection = collection {
                        let removeFromCollection = UIAction(title: "Remove from Collection", image: .init(systemName: "xmark"), attributes: .destructive)
                            { _ in
                                //
                                DataManager.shared.toggleCollection(for: content, withId: collection.id)
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

func DynamicGridLayout(header: NSCollectionLayoutDimension? = nil, footer: NSCollectionLayoutDimension? = nil, _ titleSize: CGFloat? = nil) -> UICollectionViewCompositionalLayout {
    UICollectionViewCompositionalLayout { _, environment in

        let viewingPotrait = environment.container.contentSize.width < environment.container.contentSize.height
        let itemsPerRow = UserDefaults.standard.integer(forKey: viewingPotrait ? STTKeys.GridItemsPerRow_P : STTKeys.GridItemsPerRow_LS)
        let style = TileStyle(rawValue: UserDefaults.standard.integer(forKey: STTKeys.TileStyle)) ?? .COMPACT

        let SPACING: CGFloat = 10
        let INSET: CGFloat = 16
        let totalSpacing = SPACING * CGFloat(itemsPerRow - 1)
        let groupWidth = environment.container.contentSize.width - (INSET * 2) - totalSpacing
        let estimatedItemWidth = (groupWidth / CGFloat(itemsPerRow)).rounded(.down)
        let shouldAddTitle = style == .SEPARATED && estimatedItemWidth >= 100 || titleSize != nil
        let titleSize: CGFloat = shouldAddTitle ? titleSize ?? 44 : 0
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
        section.contentInsets = .init(top: 15, leading: INSET, bottom: 10, trailing: INSET)
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
        return section
    }
}
