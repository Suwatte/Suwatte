//
//  PagingController+ContextMenu.swift
//  Suwatte
//
//  Created by Mantton on 2023-08-15.
//

import UIKit

private typealias Controller = IVPagingController

extension Controller: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration? {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)

        guard let indexPath,
              case let .page(page) = dataSource.itemIdentifier(for: indexPath)
        else { return nil }

        guard let imageView = (interaction.view as? UIImageView),
              let image = imageView.image
        else {
            return nil
        }

        let chapter = page.page.chapter
        let midPoint = collectionView.frame.midX
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { [weak self, isInverted, isDoublePager] _ in
            // Image Actions menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
                ToastManager.shared.info("Panel Saved!")
            }

            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self?.present(activityVC, animated: true, completion: nil)
            }

            let photoMenu = UIMenu(title: "", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            var target = page.page

            if isDoublePager {
                let isFirstPage = imageView.frame.minX < midPoint
                if isInverted, isFirstPage {
                    target = page.secondaryPage ?? page.page
                }
            }

            var menu = UIMenu(title: "Page \(target.index + 1)", children: [photoMenu])

            if !STTHelpers.isInternalSource(chapter.sourceId) {
                // Bookmark Actions
                let bookmarkPanelAction = UIAction(title: "Bookmark Panel", image: UIImage(systemName: "bookmark"), attributes: []) { [weak self] _ in
                    self?.addBookmark(for: target, image: image)
                }

                guard !STTHelpers.isInternalSource(target.chapter.sourceId) else {
                    menu = menu.replacingChildren([photoMenu, bookmarkPanelAction])
                    return menu
                }

                let isBookmarked = self?.model.isChapterBookmarked(id: chapter.id) ?? false
                let actionTitle = !isBookmarked ? "Bookmark Chapter" : "Remove Chapter Bookmark"
                let actionImage = !isBookmarked ? "book.closed" : "trash"
                let bookmarkChapterAction = UIAction(title: actionTitle,
                                                     image: UIImage(systemName: actionImage),
                                                     attributes: isBookmarked ? [.destructive] : [])
                { [weak self] _ in
                    self?.addChapterBookmark(for: chapter)
                }

                let bookmarkMenu = UIMenu(title: "",
                                          options: .displayInline,
                                          children: [bookmarkChapterAction, bookmarkPanelAction])

                menu = menu.replacingChildren([photoMenu, bookmarkMenu])
            }

            if isDoublePager {
                let isWide = (self?.widePages.contains(target.CELL_KEY) ?? false) || page.secondaryPage == nil
                let canMark = image.size.ratio < 1 && !(target.index == 0 && Preferences.standard.markFirstAsSingle)

                if canMark {
                    let action = UIAction(title: isWide ? "Mark As Grouped Panel" : "Mark As Single Panel",
                                          image: UIImage(systemName: "book"),
                                          attributes: [])
                    { [weak self] _ in
                        if isWide {
                            self?.pageUnmarkedAsWide(target, navigate: true)
                        } else {
                            self?.pageMarkedAsWide(target, navigate: true)
                        }
                    }
                    let doublePageMenu = UIMenu(title: "",
                                                options: .displayInline,
                                                children: [action])

                    let children = menu.children.appending(doublePageMenu)
                    menu = menu.replacingChildren(children)
                }
            }
            return menu
        })
    }

    func addBookmark(for page: ReaderPage, image: UIImage) {
        Task {
            let actor = await RealmActor.shared()
            let result = await actor.addBookmark(for: page.chapter, at: page.number, with: image)
            result ? ToastManager.shared.info("Bookmarked!") : ToastManager.shared.error("Failed to bookmark")
        }
    }

    func addChapterBookmark(for chapter: ThreadSafeChapter) {
        Task {
            let actor = await RealmActor.shared()
            let result = await actor.toggleBookmark(for: chapter)
            result ? ToastManager.shared.info("Chapter Bookmarked!") : ToastManager.shared.info("Bookmark Removed!")
        }
    }
}
