//
//  DoublePaged+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-15.
//

import UIKit

extension DoublePagedViewer.Controller: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration?
    {
        let point = interaction.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: point)

        guard let indexPath = indexPath, let page = getStack(for: indexPath.section).get(index: indexPath.item) else {
            return nil
        }

        // Get Image
        guard let imageView = (interaction.view as? UIImageView), let image = imageView.image else {
            return nil
        }

        var target: ReaderView.Page?

        // If Secondary Page is nil, return the primary page
        // Else if the interaction point is on the left side of the screen & the user is reading in the comic (->) format, use primary page else secondary
        // Make this shit readable.
        if page.secondary == nil {
            target = (page.primary as? ReaderPage)?.page
        } else {
            let primary = (page.primary as? ReaderPage)?.page
            let secondary = (page.secondary as? ReaderPage)?.page
            target = imageView.frame.minX < collectionView.frame.midX ? primary : secondary
            if !Preferences.standard.readingLeftToRight {
                if target == primary {
                    target = secondary
                } else {
                    target = primary
                }
            }
        }

        guard let target = target else { return nil }
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

            let photoMenu = UIMenu(title: "Image", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            // Toggle Bookmark
            let chapter = self.model.activeChapter.chapter

            var menu = UIMenu(title: "", children: [photoMenu])

            if chapter.chapterType != .EXTERNAL {
                return menu
            }
            // Bookmark Actions
            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter.toStored(), page: target.index)
            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"

            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
                DataManager.shared.toggleBookmark(chapter: chapter.toStored(), page: target.index)
                ToastManager.shared.info("Bookmark \(isBookmarked ? "Removed" : "Added")!")
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
            return menu
        })
    }
}
