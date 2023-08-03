//
//  PageView+Layout.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import UIKit

extension DSKPageView.CollectionView {
    func ErrorLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(200)
            ),
            subitem: item, count: 1
        )
        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))

        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 0
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        section.orthogonalScrollingBehavior = .none
        section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }

    func InfoLayout(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let columnsToFit = floor(environment.container.effectiveContentSize.width / 340)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.9 / max(1.0, columnsToFit)),
                heightDimension: .absolute(300)
            ),
            subitem: item, count: 2
        )

        itemsGroup.interItemSpacing = .fixed(10)
        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))

        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        section.orthogonalScrollingBehavior = .groupPaging
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }

    func TagsLayout() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(150),
                heightDimension: .absolute(120)
            ),
            subitem: item, count: 1
        )
        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))

        //            itemsGroup.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 7
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        section.orthogonalScrollingBehavior = .continuous
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells

        return section
    }

    func NormalLayout() -> NSCollectionLayoutSection {
        let iSeparated = UserDefaults.standard.integer(forKey: STTKeys.TileStyle) == TileStyle.SEPARATED.rawValue

        let heightDimension: NSCollectionLayoutDimension = !iSeparated ? .absolute(160 * 1.5) : .absolute((160 * 1.5) + 48)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))

        let itemsGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(160),
                heightDimension: heightDimension
            ),
            subitem: item, count: 1
        )

        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))
        let section = NSCollectionLayoutSection(group: itemsGroup)
        itemsGroup.interItemSpacing = .fixed(10)
        section.interGroupSpacing = 7
        section.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }

    func LastestLayout(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let columnsToFit = floor(environment.container.effectiveContentSize.width / 340)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))

        let itemsGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(150)
            ),
            subitem: item, count: max(1, Int(columnsToFit))
        )

        itemsGroup.interItemSpacing = .fixed(10)
        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))

        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        section.orthogonalScrollingBehavior = .none
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }

    func GalleryLayout(_: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemWidth: CGFloat = 290
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemWidth * 1.5)
            ),
            subitem: item, count: 1
        )
        itemsGroup.edgeSpacing = .init(leading: .none, top: .none, trailing: .none, bottom: .fixed(10))

        itemsGroup.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        section.orthogonalScrollingBehavior = .groupPaging
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }

    func InsetListLayout(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        var config = UICollectionLayoutListConfiguration(appearance:
            .insetGrouped)
        config.headerMode = .supplementary
        config.footerMode = .supplementary
        config.headerTopPadding = 7
        let layout: NSCollectionLayoutSection = .list(using: config, layoutEnvironment: environment)
        layout.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return layout
    }

    func GridLayout(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let viewingPotrait = environment.container.contentSize.width < environment.container.contentSize.height
        let itemsPerRow = UserDefaults.standard.integer(forKey: viewingPotrait ? STTKeys.GridItemsPerRow_P : STTKeys.GridItemsPerRow_LS)
        let style = TileStyle(rawValue: UserDefaults.standard.integer(forKey: STTKeys.TileStyle)) ?? .COMPACT

        let SPACING: CGFloat = 10
        let INSET: CGFloat = 16
        let totalSpacing = SPACING * CGFloat(itemsPerRow - 1)
        let groupWidth = environment.container.contentSize.width - (INSET * 2) - totalSpacing
        let estimatedItemWidth = (groupWidth / CGFloat(itemsPerRow)).rounded(.down)
        let shouldAddTitle = style == .SEPARATED && estimatedItemWidth >= 100
        let titleSize: CGFloat = shouldAddTitle ? 50 : 0
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
        section.contentInsets = .init(top: 13, leading: INSET, bottom: 20, trailing: INSET)
        section.interGroupSpacing = SPACING

        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        section.boundarySupplementaryItems = [supp]
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        return section
    }
}
