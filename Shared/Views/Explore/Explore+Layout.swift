//
//  Explore+Layout.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-30.
//

import UIKit

extension ExploreCollectionsController {
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

        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 0
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .none
        //        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        section.boundarySupplementaryItems = [.init(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)]
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
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .groupPaging
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells

        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        supp.contentInsets = .init(top: 0, leading: 0, bottom: 15, trailing: 0)
        section.boundarySupplementaryItems = [supp]
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

        //            itemsGroup.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 7
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .continuous
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells

        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        supp.contentInsets = .init(top: 0, leading: 0, bottom: 7, trailing: 0)
        section.boundarySupplementaryItems = [supp]

        return section
    }

    func NormalLayout() -> NSCollectionLayoutSection {
        let iSeparated = UserDefaults.standard.integer(forKey: STTKeys.TileStyle) == TileStyle.SEPARATED.rawValue
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .absolute(160),
                heightDimension: .absolute((160 * 1.5) + (iSeparated ? 50 : 0))
            ),
            subitem: item, count: 1
        )

        itemsGroup.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 7
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        supp.contentInsets = .init(top: 0, leading: 0, bottom: 15, trailing: 0)
        section.boundarySupplementaryItems = [supp]
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
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .none
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        supp.contentInsets = .init(top: 0, leading: 0, bottom: 15, trailing: 0)
        section.boundarySupplementaryItems = [supp]
        return section
    }

    func GalleryLayout(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let columnsToFit = floor(environment.container.effectiveContentSize.width / 340)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))

        let itemsGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.9 / max(1.0, columnsToFit)),
                heightDimension: .absolute(340 * 1.6)
            ),
            subitem: item, count: 1
        )

        itemsGroup.interItemSpacing = .fixed(10)
        let section = NSCollectionLayoutSection(group: itemsGroup)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        section.orthogonalScrollingBehavior = .groupPaging
        section.visibleItemsInvalidationHandler = { _, _, _ in } // If this isn't defined, there is a bug in UICVCompositional Layout that will fail to update sizes of cells
        let supp = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .topLeading)
        supp.contentInsets = .init(top: 0, leading: 0, bottom: 15, trailing: 0)
        section.boundarySupplementaryItems = [supp]
        return section
    }
}
