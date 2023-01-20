//
//  ProfileView+RelatedContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-09.
//

import ASCollectionView
import RealmSwift
import SwiftUI

extension ProfileView.Skeleton {
    struct RelatedContentView: View {
        typealias Highlight = DaisukeEngine.Structs.Highlight

        @ObservedResults(LibraryEntry.self) var library
        @ObservedResults(ReadLater.self) var readLater
        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
        var collections: [DaisukeEngine.Structs.HighlightCollection]
        @EnvironmentObject var source: DaisukeContentSource
        var body: some View {
            ASCollectionView(sections: SECTIONS)
                .layout { _ in
                    SECTION_LAYOUT()
                }
                .frame(height: COLLECTION_HEIGHT + 44 * CGFloat(SECTIONS.count))
        }

        var COLLECTION_HEIGHT: CGFloat {
            let count = collections.count
            let isSeparated = tileStyle == .SEPARATED
            let baseHeight = 150 * 1.5
            let titleHeight = (isSeparated ? 50 : 0)
            let cellHeight = CGFloat(titleHeight) + CGFloat(baseHeight)
            return CGFloat(count) * cellHeight
        }

        var SECTIONS: [ASCollectionViewSection<String>] {
            collections.map { collection in
                ASCollectionViewSection(id: collection.id, data: collection.highlights) { cellData, _ in
                    let isInLibrary = inLibrary(cellData, source.id)
                    let isSavedForLater = savedForLater(cellData, source.id)
                    ZStack(alignment: .topTrailing) {
                        NavigationLink {
                            ProfileView(entry: cellData, sourceId: source.id)
                        } label: {
                            ExploreView.HighlightTile(entry: cellData, style: .NORMAL, sourceId: source.id)
                        }
                        .buttonStyle(NeutralButtonStyle())

                        if isInLibrary || isSavedForLater {
                            ColoredBadge(color: isInLibrary ? .accentColor : .yellow)
                        }
                    }
                }
                .sectionHeader {
                    HStack {
                        VStack {
                            Text(collection.title)
                                .font(.headline.weight(.semibold))
                            if let subtitle = collection.subtitle {
                                Text(subtitle)
                                    .font(.subheadline.weight(.light))
                            }
                        }
                        Spacer()
                    }
                    .frame(height: 44)
                }
            }
        }

        func SECTION_LAYOUT() -> ASCollectionLayoutSection {
            return ASCollectionLayoutSection { _ in

                let iSeparated = tileStyle == .SEPARATED
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .fractionalHeight(1)
                ))

                let itemsGroup = NSCollectionLayoutGroup.vertical(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .absolute(150),
                        heightDimension: .absolute((150 * 1.5) + (iSeparated ? 50 : 0))
                    ),
                    subitem: item, count: 1
                )

                //            itemsGroup.interItemSpacing = .fixed(10)
                let section = NSCollectionLayoutSection(group: itemsGroup)
                section.interGroupSpacing = 7
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                section.orthogonalScrollingBehavior = .continuous
                section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
                section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
                return section
            }
        }

        func inLibrary(_ entry: Highlight, _: String) -> Bool {
            library
                .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id })
        }

        func savedForLater(_ entry: Highlight, _: String) -> Bool {
            readLater
                .contains(where: { $0.content?.sourceId == source.id && $0.content?.contentId == entry.id })
        }
    }
}
