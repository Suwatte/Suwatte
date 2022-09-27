//
//  STTImageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Kingfisher
import Nuke
import NukeUI
import RealmSwift
import SwiftUI

struct STTImageView: View {
    var url: URL?
    var identifier: ContentIdentifier
    @ObservedResults(CustomThumbnail.self) var thumbnails
    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.5)
            let processor: [ImageProcessing] = [.resize(size: size)]
            LazyImage(url: imageURL, resizingMode: .aspectFill)
                .processors(processor)
                .frame(height: proxy.size.width * 1.5, alignment: .center)
                .background(Color.gray.opacity(0.25))
        }
    }

    var imageURL: URL? {
        if hasCustomThumb {
            return STTImageProvider.urlFor(id: identifier.id)
        }
        return url
    }

    var hasCustomThumb: Bool {
        thumbnails.contains(where: { $0._id == identifier.id })
    }
}

struct BaseImageView: View {
    var url: URL?
    var mode: ImageResizingMode = .aspectFill
    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.5)
            let processor: [ImageProcessing] = [.resize(size: size)]
            LazyImage(url: url, resizingMode: mode)
                .processors(processor)
                .frame(height: proxy.size.width * 1.5, alignment: .center)
                .background(Color.gray.opacity(0.25))
        }
    }
}

class AsyncImageModifier: AsyncImageDownloadRequestModifier {
    init(sourceId:String?) {
        self.sourceId = sourceId
    }
    let sourceId: String?
    func modified(for request: URLRequest, reportModified: @escaping (URLRequest?) -> Void) {
        guard let sourceId, let source = DaisukeEngine.shared.getSource(with: sourceId)  else {
            reportModified(request)
            return
        }
        do {
            let req = try request.toDaisukeNetworkRequest()
            Task {
                let modified = try await source.willRequestImage(request: req)
                if let modified {
                    try Task.checkCancellation()
                    reportModified(try modified.toURLRequest())
                } else {
                    reportModified(request)
                }
            }
        } catch {
            reportModified(request)
        }
        
    }

    var onDownloadTaskStarted: ((DownloadTask?) -> Void)?
}
