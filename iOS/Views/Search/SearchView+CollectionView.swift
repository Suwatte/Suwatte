//
//  SearchView+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import ASCollectionView
import SwiftUI

extension SearchView {
    struct CollectionView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            ASCollectionView(sections: CollectionSections)
                .alwaysBounceVertical()
                .layout(scrollDirection: .vertical, interSectionSpacing: 7, layoutPerSection: { _ in
                    LoadedLayout()
                })
                .animateOnDataRefresh(true)
                .shouldInvalidateLayoutOnStateChange(true)
        }
    }
}

// MARK: Sections

extension SearchView.CollectionView {
    var CollectionSections: [ASCollectionViewSection<String>] {
        model
            .results
            .map(CollectionSection(_:))
    }

    func CollectionSection(_ result: SearchView.ResultGroup) -> ASCollectionViewSection<String> {
        .init(id: result.sourceID, data: result.result.results) { data, _ in
            CollectionCell(data: data, sourceID: result.sourceID)
        }
        .sectionHeader {
            CollectionHeader(result)
        }
    }
}

// MARK: Layout

extension SearchView.CollectionView {
    func LoadedLayout() -> ASCollectionLayoutSection {
        return ASCollectionLayoutSection { _ in
            let style = TileStyle(rawValue: UserDefaults.standard.integer(forKey: STTKeys.TileStyle)) ?? .COMPACT

            let isSeparated = style == .SEPARATED
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalHeight(1)
            ))

            let itemsGroup = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .absolute(150),
                    heightDimension: .absolute((150 * 1.5) + (isSeparated ? 50 : 0))
                ),
                subitem: item, count: 1
            )

            //            itemsGroup.interItemSpacing = .fixed(10)
            let section = NSCollectionLayoutSection(group: itemsGroup)
            section.interGroupSpacing = 7
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 5)
            section.orthogonalScrollingBehavior = .continuous
            section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
            section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
            return section
        }
    }
}

// MARK: Header

extension SearchView.CollectionView {
    @ViewBuilder
    func CollectionHeader(_ group: SearchView.ResultGroup) -> some View {
        let result = group.result
        HStack {
            VStack(alignment: .leading) {
                Text(group.sourceName)
                    .font(.headline.weight(.semibold))

                let count = result.totalResultCount ?? result.results.count
                Text("\(count.description)\(result.isLastPage ? "" : "+") results")
                    .font(.subheadline.weight(.light))
            }
            Spacer()
            if !result.isLastPage {
                NavigationLink {
                    LoadableSourceView(sourceID: group.sourceID) { source in
                        ContentSourceDirectoryView(source: source,
                                                   request: .init(query: model.query,
                                                                  page: 1))
                    }
                } label: {
                    Text("View More \(Image(systemName: "chevron.right"))")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentColor)
                .font(.caption)
            }
        }
        .padding(.vertical)
    }
}

// MARK: Cell

extension SearchView.CollectionView {
    struct CollectionCell: View {
        let data: DSKCommon.Highlight
        let sourceID: String
        @EnvironmentObject private var model: SearchView.ViewModel
        var body: some View {
            NavigationLink {
                ProfileView(entry: data, sourceId: sourceID)
            } label: {
                DefaultTile(entry: data, sourceId: sourceID)
            }
            .buttonStyle(NeutralButtonStyle())
            .coloredBadge(badge)
        }

        // Computed :]
        var identifier: String {
            ContentIdentifier(contentId: data.id, sourceId: sourceID).id
        }

        var inLibrary: Bool {
            model.library.contains(identifier) || model.libraryLinked.contains(identifier)
        }

        var inReadLater: Bool {
            model.savedForLater.contains(identifier)
        }

        var badge: Color? {
            if inLibrary { return .accentColor }
            if inReadLater { return .yellow }
            return nil
        }
    }
}
