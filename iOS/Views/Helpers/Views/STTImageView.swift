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
    @EnvironmentObject var appState: StateManager
    @StateObject private var loader = FetchImage()
    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.6)
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
            .frame(width: proxy.size.width, height: proxy.size.width * 1.6, alignment: .center)
            .background(Color.gray.opacity(0.25))
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
            .onChange(of: appState.titleHasCustomThumbs) { _ in
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

                let runner = DSK.shared.getRunner(identifier.sourceId)
                guard let runner, runner.intents.imageRequestHandler else {
                    loader.load(url)
                    return
                }

                do {
                    let response = try await runner.willRequestImage(imageURL: url)
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
        let id = identifier.id
        if appState.titleHasCustomThumbs.contains(id) {
            return DataManager.shared.getCustomThumb(id: id)?.file?.filePath
        }
        return nil
    }
}

struct BaseImageView: View {
    var url: URL?
    var request: ImageRequest?
    var runnerId: String?
    var mode: SwiftUI.ContentMode = .fill
    @StateObject private var loader = FetchImage()
    @State var isVisible = false
    @Environment(\.placeholderImageShimmer) var shimmer

    var body: some View {
        GeometryReader { proxy in
            let size: CGSize = .init(width: proxy.size.width, height: proxy.size.width * 1.6)
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
            .task { await load(size, url) }
            .onDisappear {
                loader.reset()
                loader.priority = .low
                isVisible = false
            }
            .frame(width: proxy.size.width, height: proxy.size.width * 1.6, alignment: .center)
            .background(Color.gray.opacity(0.25))
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
            .onChange(of: url) { value in
                Task {
                    await load(size, value)
                }
            }
        }
    }

    func load(_ size: CGSize, _ url: URL?) async {
        isVisible = true
        if loader.image != nil { return }
        loader.processors = [NukeDownsampleProcessor(size: size)]
        loader.transaction = .init(animation: .easeInOut(duration: 0.25))
        loader.priority = .normal
        loader.onCompletion = onImageEvent
        if let request {
            loader.load(request)
            return
        }
        
        guard let url else { return }

        guard url.isHTTP else {
            loader.load(url)
            return
        }
        // Source Has Image Request Handler, prevents sources from being initialized unecessarily
        guard let runnerId, UserDefaults.standard.bool(forKey: STTKeys.RunnerOverridesImageRequest(runnerId)) else {
            loader.load(url)
            return
        }
        guard let runner = DSK.shared.getRunner(runnerId), runner.intents.imageRequestHandler else {
            loader.load(url)
            return
        }

        do {
            let response = try await runner.willRequestImage(imageURL: url)
            let request = try ImageRequest(urlRequest: response.toURLRequest())
            loader.load(request)
        } catch {
            Logger.shared.error(error.localizedDescription)
            loader.load(url)
        }
    }

    func onImageEvent(_ result: Result<ImageResponse, Error>) {
        switch result {
        case .success:
            break
        case let .failure(error):
            Logger.shared.error(error, "ImageLoader")
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
