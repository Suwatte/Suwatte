//
//  WebtoonController+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import UIKit

private typealias Controller = WebtoonController

extension Controller {
    func captureVisibleRect(of view: UIView) -> UIImage? {
        let offset = collectionNode.contentOffset
        let visibleRect = CGRect(x: offset.x,
                                 y: offset.y,
                                 width: view.bounds.width,
                                 height: view.bounds.height)

        UIGraphicsBeginImageContextWithOptions(visibleRect.size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: -visibleRect.origin.x, y: -visibleRect.origin.y)
        view.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

extension Controller: UIContextMenuInteractionDelegate, UIGestureRecognizerDelegate {
    func contextMenuInteraction(_: UIContextMenuInteraction, configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration? {
        guard let currentPath,
              let item = dataSource.itemIdentifier(for: currentPath),
              case let .page(page) = item else { return nil }
        let image = captureVisibleRect(of: collectionNode.view)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            // Create and return a preview for the visible portion of the image
            let previewVC = UIViewController()
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: UIScreen.main.bounds.size))
            imageView.contentMode = .scaleAspectFit
            imageView.image = image
            previewVC.view = imageView
            return previewVC
        }, actionProvider: { _ in
            guard let image else { return nil }
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

            let panelMenu = UIMenu(title: "", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            var menu = UIMenu(title: "Actions", children: [panelMenu])

            let bookmarkPanelAction = UIAction(title: "Bookmark",
                                               image: UIImage(systemName: "bookmark"),
                                               attributes: [])
            { [weak self] _ in
                self?.addBookmark(image: image)
            }

            guard !STTHelpers.isInternalSource(page.page.chapter.sourceId) else {
                menu = menu.replacingChildren([panelMenu, bookmarkPanelAction])
                return menu
            }
            let chapter = page.page.chapter

            let isBookmarked = self.model.isChapterBookmarked(id: chapter.id)
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

            menu = menu.replacingChildren([panelMenu, bookmarkMenu])
            return menu
        })
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor _: UIContextMenuConfiguration, animator _: UIContextMenuInteractionAnimating?) {
        navigationController?.view.removeInteraction(interaction)
    }

    func addBookmark(image: UIImage) {
        guard let currentPath, let item = dataSource.itemIdentifier(for: currentPath), case let .page(page) = item else { return }
        let offset = calculateCurrentOffset(of: currentPath)
        Task {
            let actor = await RealmActor.shared()
            let result = await actor.addBookmark(for: page.page.chapter,
                                                 at: page.page.number,
                                                 with: image,
                                                 on: offset)
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
