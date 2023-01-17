//
//  DoublePaged+Combine.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-15.
//
import UIKit

fileprivate typealias ImageCell = DoublePagedViewer.ImageCell
extension DoublePagedViewer.Controller {
    func listen() {
        // MARK: LTR & RTL Publisher

        Preferences.standard.preferencesChangedSubject
            .filter { \Preferences.readingLeftToRight == $0 }
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.transformView()
                    self?.collectionView.collectionViewLayout.invalidateLayout()
                    self?.updateSliderOffset()
                }
            }
            .store(in: &subscriptions)

        // MARK: Reload Publisher

        model.reloadPublisher.sink { [weak self] in
            DispatchQueue.main.async {
                self?.collectionView.reloadData()
                self?.collectionView.scrollToItem(at: .init(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            }

        }.store(in: &subscriptions)

        // MARK: Slider Publisher

        model.$slider.sink { [unowned self] slider in
            if slider.isScrubbing {
                let position = getPositionRelativeTo(slider.current)

                if let path = collectionView.indexPathForItem(at: position),
                   let cell = collectionView.cellForItem(at: path) as? ImageCell,
                   let pView = cell.pageView {
                    let page = pView.secondPage?.page ?? pView.page.page 
                    model.scrubbingPageNumber = page.index + 1
                }
                
                collectionView.setContentOffset(position, animated: false)
            }
        }
        .store(in: &subscriptions)

        // MARK: DID END SCRUBBING PUBLISHER

        model.scrubEndPublisher.sink { [unowned self] in
            guard let currentPath = currentPath else {
                return
            }
            collectionView.scrollToItem(at: currentPath, at: .centeredHorizontally, animated: true)
        }
        .store(in: &subscriptions)

        // MARK: DID PREFERENCE CHANGE PUBLISHER

        Preferences.standard.preferencesChangedSubject
            .filter { changedKeyPath in
                changedKeyPath == \Preferences.forceTransitions ||
                    changedKeyPath == \Preferences.imageInteractions
            }
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.collectionView.reloadData()
                }
            }
            .store(in: &subscriptions)

        // MARK: Navigation Publisher

        model.navigationPublisher.sink { [unowned self] action in
            let rtl = Preferences.standard.readingLeftToRight

            var isPreviousTap = action == .LEFT
            if !rtl { isPreviousTap.toggle() }

            let width = collectionView.frame.width
            let offset = isPreviousTap ? collectionView.currentPoint.x - width : collectionView.currentPoint.x + width

            let path = collectionView.indexPathForItem(at: .init(x: offset, y: 0))

            if let path = path {
                collectionView.scrollToItem(at: path, at: .centeredHorizontally, animated: true)
            }
        }
        .store(in: &subscriptions)

        // MARK: Insert Publisher

        model.insertPublisher.sink { [unowned self] section in
            
            Task { @MainActor in
                let topInsertion = section == 0 && model.sections.count != 0
//                 Next Chapter Logic
                if topInsertion {
                    moveStackCache()
                }
                let data = generatePages(for: section)
                let paths = data.indices.map { IndexPath(item: $0, section: section) }

                let layout = collectionView.collectionViewLayout as? HorizontalContentSizePreservingFlowLayout

                layout?.isInsertingCellsToTop = topInsertion

                CATransaction.begin()
                CATransaction.setDisableActions(true)

                collectionView.performBatchUpdates({
                    let set = IndexSet(integer: section)
                    collectionView.insertSections(set)
                    collectionView.insertItems(at: paths)
                }) { finished in
                    if finished {
                        CATransaction.commit()
                    }
                }
            }

        }.store(in: &subscriptions)
    }

    func moveStackCache() {
        let keys = cache.keys.reversed()

        for key in keys {
            cache[key + 1] = cache[key]
        }
        cache.removeValue(forKey: 0)
    }
}
