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
    var mode: SwiftUI.ContentMode = .fill
    @ObservedResults(CustomThumbnail.self) var thumbnails
    @StateObject private var loader = FetchImage()

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.5)
            Group {
                if let view = loader.view {
                    view
                        .resizable()
                        .aspectRatio(contentMode: mode)
                } else {
                    Color.gray.opacity(0.25)
                        .shimmering()
                }
            }
            .task {
                load(size)
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.5, alignment: .center)
            .background(Color.gray.opacity(0.25))
        }
    }

    func load(_ size: CGSize) {
        loader.processors = [.resize(size: size)]
        loader.animation = .easeOut(duration: 0.25)
        guard let imageURL, imageURL.isHTTP else {
            loader.load(url)
            return
        }
        Task {
            let source = DaisukeEngine.shared.getJSSource(with: identifier.sourceId)
            let req = try? await source?.willRequestImage(request: .init(url: imageURL.absoluteString))?.toURLRequest()
            loader.load(req ?? imageURL)
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
    var sourceId: String?
    var mode: SwiftUI.ContentMode = .fill
    @StateObject private var loader = FetchImage()

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.5)
            Group {
                if let view = loader.view {
                    view
                        .resizable()
                        .aspectRatio(contentMode: mode)
                } else {
                    Color.gray.opacity(0.25)
                        .shimmering()
                }
            }
            .task {
                load(size)
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.5, alignment: .center)
            .background(Color.gray.opacity(0.25))
        }
    }

    func load(_ size: CGSize) {
        loader.processors = [.resize(size: size)]
        loader.animation = .easeOut(duration: 0.25)

        guard let url, url.isHTTP else {
            loader.load(url)
            return
        }
        Task {
            if let sourceId = sourceId, let source = DaisukeEngine.shared.getJSSource(with: sourceId) {
                let req = try? await source.willRequestImage(request: .init(url: url.absoluteString))?.toURLRequest()
                loader.load(req ?? url)
                return
            }
            loader.load(url)
        }
    }
}

class AsyncImageModifier: AsyncImageDownloadRequestModifier {
    init(sourceId: String?) {
        self.sourceId = sourceId
    }

    let sourceId: String?
    func modified(for request: URLRequest, reportModified: @escaping (URLRequest?) -> Void) {
        guard let sourceId, let source = DaisukeEngine.shared.getJSSource(with: sourceId) else {
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
