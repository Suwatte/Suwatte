//
//  STTImageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Alamofire
import Nuke
import NukeUI
import RealmSwift
import SwiftUI
struct STTImageView: View {
    var url: URL?
    var identifier: ContentIdentifier
    var mode: SwiftUI.ContentMode = .fill
    @Environment(\.placeholderImageShimmer) var shimmer

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
                        .shimmering(active: shimmer)
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
        
        
        guard let url else { return }

        
        Task {
            if identifier.sourceId == STTHelpers.OPDS_CONTENT_ID {
                let pub = DataManager.shared.getPublication(id: identifier.contentId)
                let value = pub?.client?.toClient().authHeader
                guard let value else {
                    loader.load(url)
                    return
                }
                do {
                    let req = try URLRequest(url: url, method: .get, headers: .init([.init(name: "Authorization", value: value)]))
                    let nukeReq = ImageRequest(urlRequest: req)
                    loader.load(nukeReq)
                } catch {
                    Logger.shared.error(error)
                    loader.load(url)
                }
            } else {
                // Source Has Image Request Handler, prevents sources from being initialized unecessarily
                guard UserDefaults.standard.bool(forKey: STTKeys.RunnerOverridesImageRequest(identifier.sourceId)) else {
                    loader.load(url)
                    return
                }
                
                let source = DSK.shared.getSource(id: identifier.sourceId)
                guard let source, source.intents.imageRequestHandler else {
                    loader.load(url)
                    return
                }
                
                do {
                    let response = try await source.willRequestImage(imageURL: url)
                    let request = try ImageRequest(urlRequest: response.toURLRequest())
                    loader.load(request)
                } catch {
                    Logger.shared.error(error.localizedDescription)
                    loader.load(url)
                }
            }
        }
    }

    var customThumbanailURL: URL? {
        thumbnails.where { $0.id == identifier.id }.first?.file?.filePath
    }
}

struct BaseImageView: View {
    var url: URL?
    var request: ImageRequest?
    var sourceId: String?
    var mode: SwiftUI.ContentMode = .fill
    @StateObject private var loader = FetchImage()
    @State var isVisible = false
    @Environment(\.placeholderImageShimmer) var shimmer

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
                        .shimmering(active: shimmer && isVisible)
                }
            }
            .onAppear { load(size) }
            .onDisappear {
                loader.reset()
                loader.priority = .low
                isVisible = false
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.5, alignment: .center)
            .background(Color.gray.opacity(0.25))
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
        }
    }

    func load(_ size: CGSize) {
        isVisible = true
        if loader.image != nil { return }
        loader.processors = [NukeDownsampleProcessor(size: size)]
        loader.transaction = .init(animation: .easeInOut(duration: 0.25))
        loader.priority = .normal
        
        if let request {
            loader.load(request)
            return
        }
        
        guard let url, url.isHTTP else {
            loader.load(url)
            return
        }
        // Source Has Image Request Handler, prevents sources from being initialized unecessarily
        guard let sourceId, UserDefaults.standard.bool(forKey: STTKeys.RunnerOverridesImageRequest(sourceId)) else {
            loader.load(url)
            return
        }
        guard let source = DSK.shared.getSource(id: sourceId), source.intents.imageRequestHandler else {
            loader.load(url)
            return
        }
        
        Task {
            do {
                let response = try await source.willRequestImage(imageURL: url)
                let request = try ImageRequest(urlRequest: response.toURLRequest())
                loader.load(request)
            } catch {
                Logger.shared.error(error.localizedDescription)
                loader.load(url)
            }
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

private struct ImageShimmerKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var placeholderImageShimmer: Bool {
        get { self[ImageShimmerKey.self] }
        set { self[ImageShimmerKey.self] = newValue }
    }
}
