//
//  STTImageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Nuke
import NukeUI
import RealmSwift
import SwiftUI

struct STTImageView: View {
    var url: URL?
    var identifier: ContentIdentifier
    var mode: SwiftUI.ContentMode = .fill
    @ObservedResults(CustomThumbnail.self, where: { $0.isDeleted == false }) var thumbnails
    @StateObject private var loader = FetchImage()
    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.5)
            Group {
                if let view = loader.image {
                    view
                        .resizable()
                        .aspectRatio(contentMode: mode)
                        .transition(.opacity)
                } else {
                    Color.gray.opacity(0.25)
                        .shimmering()
                }
            }
            .task { load(size) }
            .onDisappear {
                loader.priority = .low
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.5, alignment: .center)
            .background(Color.gray.opacity(0.25))
//            .modifier(DisabledNavLink())
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
            .onChange(of: customThumbanailURL) { _ in
                Task {
                    loader.reset()
                    load(size)
                }
            }
        }
    }

    func load(_ size: CGSize) {
        if loader.image != nil { return }
        loader.priority = .normal
        loader.transaction = .init(animation: .easeInOut(duration: 0.25))
        loader.processors = [NukeDownsampleProcessor(size: size)]
        
        if let customThumbanailURL {
            loader.load(customThumbanailURL)
            return
        }
        Task {
            let source = SourceManager.shared.getSource(id: identifier.sourceId)

            do {
                if let source = source as? any ModifiableSource, source.config.hasThumbnailInterceptor {
                    let dskRequest = DSKCommon.Request(url: url?.absoluteString ?? "")
                    let dskResponse = try await source.willRequestImage(request: dskRequest)
                    let imageRequest = ImageRequest(urlRequest: try dskResponse.toURLRequest())
                    loader.load(imageRequest)
                    return
                }
            } catch {
                Logger.shared.error(error.localizedDescription)
            }

            loader.load(url)
        }
    }

    var customThumbanailURL: URL? {
        thumbnails.where({ $0.id == identifier.id }).first?.file?.filePath
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
                if let view = loader.image {
                    view
                        .resizable()
                        .aspectRatio(contentMode: mode)
                        .transition(.opacity)
                } else {
                    Color.gray.opacity(0.25)
                        .shimmering()
                }
            }
            .onAppear { load(size) }
            .onDisappear {
                loader.reset()
                loader.priority = .low
                
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.5, alignment: .center)
            .background(Color.gray.opacity(0.25))
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
        }
    }

    func load(_ size: CGSize) {
        if loader.image != nil { return }
        loader.processors = [NukeDownsampleProcessor(size: size)]
        loader.transaction = .init(animation: .easeInOut(duration: 0.25))
        loader.priority = .normal
        guard let url, url.isHTTP else {
            loader.load(url)
            return
        }
        Task {
            do {
                if let sourceId, let source = SourceManager.shared.getSource(id: sourceId) as? any ModifiableSource, source.config.hasThumbnailInterceptor {
                    let dskRequest = DSKCommon.Request(url: url.absoluteString)
                    let dskResponse = try await source.willRequestImage(request: dskRequest)
                    let imageRequest = ImageRequest(urlRequest: try dskResponse.toURLRequest())
                    loader.load(imageRequest)
                } else {
                    loader.load(url)
                }
            } catch {
                Logger.shared.error(error.localizedDescription)
            }

            loader.load(url)
        }
    }
}

struct DisabledNavLink: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                NavigationLink {
                    EmptyView()
                } label: {
                    EmptyView()
                }
                .opacity(0)
//                .disabled(true)
            }
    }
}
