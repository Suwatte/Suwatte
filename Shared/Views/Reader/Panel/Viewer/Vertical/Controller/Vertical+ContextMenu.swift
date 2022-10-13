//
//  Vertical+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-12.
//

import UIKit
import AsyncDisplayKit
import Kingfisher
import SwiftUI

fileprivate typealias Controller = VerticalViewer.AsyncController

extension Controller: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration?
    {
        let point = interaction.location(in: collectionNode.view)
        let indexPath = collectionNode.indexPathForItem(at: point)
        guard let indexPath else { return nil }
        let node = collectionNode.nodeForItem(at: indexPath) as? Controller.ImageNode
        guard let image = node?.imageNode.image else { return nil}


        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in

            // Image Actiosn menu
            // Save to Photos
            let saveToAlbum = UIAction(title: "Save Panel", image: UIImage(systemName: "square.and.arrow.down")) { _ in
                STTPhotoAlbum.shared.save(image)
            }

            // Share Photo
            let sharePhotoAction = UIAction(title: "Share Panel", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let objectsToShare = [image]
                let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityVC, animated: true, completion: nil)
            }

            let photoMenu = UIMenu(title: "Image Actions", options: .displayInline, children: [saveToAlbum, sharePhotoAction])

            // Toggle Bookmark
            let chapter = self.model.activeChapter.chapter
            let page = indexPath.item + 1

            var menu = UIMenu(title: "", children: [photoMenu])

            if chapter.chapterType != .EXTERNAL {
                return menu
            }
            // Bookmark Actions
            let isBookmarked = DataManager.shared.isBookmarked(chapter: chapter, page: page)
            let bkTitle = isBookmarked ? "Remove Bookmark" : "Bookmark Panel"
            let bkSysImage = isBookmarked ? "bookmark.slash" : "bookmark"

            let bookmarkAction = UIAction(title: bkTitle, image: UIImage(systemName: bkSysImage), attributes: isBookmarked ? [.destructive] : []) { _ in
                DataManager.shared.toggleBookmark(chapter: chapter, page: page)
            }

            menu = menu.replacingChildren([photoMenu, bookmarkAction])
            return menu
        })
    }
}
