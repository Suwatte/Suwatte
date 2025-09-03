//
//  WebtoonController+Slider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

private typealias Controller = WebtoonController

// MARK: G1

extension Controller {
    func updateChapterScrollRange() {
        currentChapterRange = getScrollRange()
    }

    func scrollPosition(for pct: Double) -> CGFloat {
        let total = currentChapterRange.max - currentChapterRange.min
        var amount = total * pct
        amount += currentChapterRange.min
        return amount
    }

    func setScrollPCT() {
        let contentOffset = offset
        let total = currentChapterRange.max - currentChapterRange.min
        var current = contentOffset - currentChapterRange.min
        current = max(0, current)
        current = min(currentChapterRange.max, current)
        var target = Double(current) / Double(total)
        if target.isNaN {
            target = 1.0
        }

        Task { @MainActor [weak self] in
            self?.model.slider.current = target
        }
    }
}

// MARK: G2

extension Controller {
    func handleSliderPositionChange(_ value: Double) {
        guard model.slider.isScrubbing else {
            return
        }
        let position = scrollPosition(for: value)
        let point = CGPoint(x: 0,
                            y: position)

        defer {
            collectionNode
                .setContentOffset(point, animated: false)
        }
        guard let path = collectionNode.indexPathForItem(at: point),
              case let .page(page) = dataSource.itemIdentifier(for: path)
        else {
            return
        }

        model.viewerState.page = page.page.number
    }

    func getScrollRange() -> (min: CGFloat, max: CGFloat) {
        let def: (min: CGFloat, max: CGFloat) = (min: .zero, max: .zero)
        var sectionMinOffset: CGFloat = .zero
        var sectionMaxOffset: CGFloat = .zero
        // Get Current IP
        guard let path = pathAtCenterOfScreen else {
            return def
        }
        let item = dataSource.itemIdentifier(for: path)
        guard let item else { return def }
        let section = dataSource.itemIdentifiers(inSection: item.chapter.id)

        let minIndex = section.firstIndex(where: \.isPage) // O(1)
        let maxIndex = max(section.endIndex - 2, 0)

        // CollectionView
        let collectionView = collectionNode.view
        // Get Min
        if let minIndex {
            let attributes = collectionView.layoutAttributesForItem(at: .init(item: minIndex, section: path.section))

            if let attributes {
                let frame = attributes.frame
                sectionMinOffset = frame.minY
            }
        }

        // Get Max
        let attributes = collectionView.layoutAttributesForItem(at: .init(item: maxIndex, section: path.section))
        if let attributes {
            let frame = attributes.frame
            sectionMaxOffset = frame.maxY - collectionNode.frame.height
        }

        return (min: sectionMinOffset, max: sectionMaxOffset)
    }
}
