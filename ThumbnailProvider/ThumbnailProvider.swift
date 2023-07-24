//
//  ThumbnailProvider.swift
//  ThumbnailProvider
//
//  Created by Mantton on 2023-06-20.
//

import QuickLookThumbnailing
import UIKit

class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let url = request.fileURL

        do {
            // Get Thumbnail
            print("Called", url)
            let image = try ArchiveHelper().getThumbnail(for: url)

            print("Done", url)
            let maximumSize = request.maximumSize
            let originalSize = image.size

            let aspectRatio = originalSize.width / originalSize.height
            let aspectWidth = min(maximumSize.width, maximumSize.height * aspectRatio)
            let aspectHeight = min(maximumSize.height, maximumSize.width / aspectRatio)
            let contextSize = CGSize(width: aspectWidth, height: aspectHeight)
            // Prepare Reply
            let reply = QLThumbnailReply(contextSize: contextSize) {
                image.draw(in: CGRect(origin: .zero, size: contextSize))
                return true
            }

            // Call Completion Handler
            Task { @MainActor in
                handler(reply, nil)
            }

        } catch {
            print(error)
            print("CAUGHT")
            Task { @MainActor in
                handler(nil, error)
            }
        }
    }
}
