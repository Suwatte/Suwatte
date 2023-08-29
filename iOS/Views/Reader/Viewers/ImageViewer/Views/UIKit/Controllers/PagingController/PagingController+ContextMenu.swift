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
              case let .page(page) = dataSource.itemIdentifier(for: indexPath),
              let image = (interaction.view as? UIImageView)?.image
        else { return nil }

        let chapter = page.page.chapter
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in

            // Image Actiosn menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
                ToastManager.shared.info("Panel Saved!")
            }

            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }

            let photoMenu = UIMenu(title: "", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            var menu = UIMenu(title: "Page \(page.page.index + 1)", children: [photoMenu])

            guard !STTHelpers.isInternalSource(chapter.sourceId) else { return menu }

            // Bookmark Actions
            let bookmarkAction = UIAction(title: "Bookmark Panel", image: UIImage(systemName: "bookmark"), attributes: []) { [weak self] _ in
                self?.addBookmark(for: page.page, image: image)
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
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
}
