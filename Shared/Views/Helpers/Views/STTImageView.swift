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
    var identifier: DaisukeEngine.Structs.SuwatteContentIdentifier
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
    func modified(for request: URLRequest, reportModified: @escaping (URLRequest?) -> Void) {
        var r = request
        r.setValue(STT_USER_AGENT, forHTTPHeaderField: "User-Agent")
        reportModified(r)
    }

    var onDownloadTaskStarted: ((DownloadTask?) -> Void)?
}
