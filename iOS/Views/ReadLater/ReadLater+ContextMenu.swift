//
//  ReadLater+ContextMenu.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-26.
//

import Foundation
import SwiftUI
import UIKit

extension LibraryView.ReadLaterView.CollectionView {
    func inLibrary(_ entry: ReadLater) -> Bool {
        model.library.contains(entry.id) || model.libraryLinked.contains(entry.id)
    }

    func contextMenuProvider(int _: Int, entry: ReadLater) -> UIContextMenuConfiguration? {
        guard let content = entry.content?.thaw() else {
            return nil
        }
        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ -> UIMenu? in
            var actions = [UIAction]()
            let removeAction = UIAction(title: "Remove from Read Later", image: UIImage(systemName: "bookmark.slash"), attributes: .destructive) {
                _ in
                Task {
                    let actor = await RealmActor.shared()
                    await actor
                        .removeFromReadLater(content.sourceId,
                                             content: content.contentId)
                }
            }
            actions.append(removeAction)

            if !inLibrary(entry) {
                let moveAction = UIAction(title: "Move to Library", image: UIImage(systemName: "folder")) {
                    _ in
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.removeFromReadLater(content.sourceId, content: content.contentId)
                        await actor.toggleLibraryState(for: content.ContentIdentifier)
                    }
                }
                actions.append(moveAction)
            }

            return .init(title: "", children: actions)
        }
        return configuration
    }
}
