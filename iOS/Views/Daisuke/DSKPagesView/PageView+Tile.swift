//
//  PageView+Tile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import Nuke
import NukeUI
import SwiftUI

struct PageViewTile: View {
    let runnerID: String
    let id: String
    let title: String
    let subtitle: String?
    let cover: String
    let additionalCovers: [String]?
    let info: [String]?
    let badge: DSKCommon.Badge?
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
    @Environment(\.pageSectionStyle) var style

    var body: some View {
        ZStack {
            switch style {
            case .DEFAULT: NORMAL
            case .INFO: INFO
            case .GALLERY: GALLERY(runnerID: runnerID, id: id, title: title, subtitle: subtitle, cover: cover, additionalCovers: additionalCovers, info: info, badge: badge)
            case .PADDED_LIST: LATEST
            case .ITEM_LIST: LIST
            case .NAVIGATION_LIST: NAVIGATION_LIST
            case .STANDARD_GRID: GRID
            case .TAG: TAG(title: title, imageUrl: cover, runnerID: runnerID)
            }
        }
    }
}

// MARK: - Info Style Tile

extension PageViewTile {
    var INFO: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: cover), identifier: .init(contentId: id, sourceId: runnerID))
                .frame(width: 100)
                .cornerRadius(5)
                .padding(.all, 5)
                .shadow(radius: 2.5)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                TAGS_VIEW
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
            Spacer()
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(5)
    }
}

// MARK: - Tags view

extension PageViewTile {
    var TAGS_VIEW: some View {
        VStack(alignment: .leading) {
            ForEach(info ?? []) {
                Text($0)
                    .lineLimit(2)
            }
        }
        .multilineTextAlignment(.leading)
        .clipped()
        .font(.subheadline.weight(.thin))
    }
}

// MARK: - DEFAULT

extension PageViewTile {
    var NORMAL: some View {
        DefaultTile(entry: .init(id: id, cover: cover, title: title, subtitle: subtitle), sourceId: runnerID)
            .dskBadge(badge)
    }
}

extension PageViewTile {
    var LATEST: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: cover), identifier: .init(contentId: id, sourceId: runnerID))
                .frame(width: 95)
                .cornerRadius(5)
                .dskBadge(badge)
                .padding(.all, 7)
                .shadow(radius: 2.5)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                TAGS_VIEW
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
            Spacer()
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(5)
    }
}

// MARK: - Gallery View

extension PageViewTile {
    struct GALLERY: View {
        let runnerID: String
        let id: String
        let title: String
        let subtitle: String?
        let cover: String
        let additionalCovers: [String]?
        let info: [String]?
        let badge: DSKCommon.Badge?

        @State private var endColor = Color.black
        @State private var timer: Timer?
        @State private var currentImageIndex = 0
        private let prefetcher = ImagePrefetcher()

        private var covers: [String] {
            Array(
                Set([cover] + (additionalCovers ?? []))
            )
        }

        @StateObject private var loader = FetchImage()
        private var urls: [URL] {
            return covers.compactMap { URL(string: $0) }
        }

        var body: some View {
            ZStack(alignment: .bottom) {
                ZStack {
                    if let view = loader.image {
                        GeometryReader { proxy in
                            view
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: proxy.size.width * 1.5, alignment: .center)
                        }
                        .transition(.opacity)

                    } else {
                        Color.gray.opacity(0.25)
                    }
                }

                LinearGradient(gradient: Gradient(colors: [.clear, endColor]), startPoint: .center, endPoint: .bottom)
                VStack {
                    // Image Carasouel
                    Text(title)
                        .multilineTextAlignment(.center)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .lineLimit(2)
                    }

                    VStack(alignment: .center) {
                        ForEach(info ?? []) {
                            Text($0)
                                .lineLimit(2)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .font(.footnote.weight(.light))

                    if covers.count > 1 {
                        HStack {
                            ForEach(covers, id: \.self) { cover in
                                Rectangle()
                                    .frame(height: 3.5, alignment: .center)
                                    .foregroundColor(.white.opacity((currentImageIndex == covers.firstIndex(of: cover)!) ? 1.0 : 0.25))
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .foregroundColor(.white)
                .padding()
            }
            .animation(.default, value: loader.image)
            .cornerRadius(5)
            .task {
                await setup()
            }
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
        }

        func load(url: URL?) async {
            guard let url else { return }
            // Source Has Image Request Handler, prevents sources from being initialized unecessarily
            guard UserDefaults.standard.bool(forKey: STTKeys.RunnerOverridesImageRequest(runnerID)) else {
                loader.load(url)
                return
            }

            let runner = await DSK.shared.getRunner(runnerID)
            guard let runner, runner.intents.imageRequestHandler else {
                loader.load(url)
                return
            }

            do {
                let response = try await runner.willRequestImage(imageURL: url)
                let request = try ImageRequest(urlRequest: response.toURLRequest())
                loader.load(request)
            } catch {
                Logger.shared.error(error.localizedDescription, "ImageView")
                loader.load(url)
            }
        }

        func setup() async {
            // Update Loader
            loader.transaction = .init(animation: .easeInOut(duration: 0.25))
            await load(url: urls.first)

            guard urls.count > 1 else { return }
        }
    }
}

// MARK: - Standard List

extension PageViewTile {
    var LIST: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: cover), identifier: .init(contentId: id, sourceId: runnerID))
                .frame(width: 90)
                .cornerRadius(5)
                .shadow(radius: 2.5)
                .dskBadge(badge)
                .padding(.all, 7)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                TAGS_VIEW
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
        }
        .frame(height: 145, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

// MARK: - NavigationList

extension PageViewTile {
    var NAVIGATION_LIST: some View {
        HStack(alignment: .center, spacing: 5) {
            // Image
            STTThumbView(url: URL(string: cover))
                .frame(width: 44, height: 44)
                .cornerRadius(5)
                .shadow(radius: 2.5)
                .dskBadge(badge)
                .padding(.all, 7)

            VStack(alignment: .center) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
        }
        .frame(height: 65, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

extension PageViewTile {
    var GRID: some View {
        DefaultTile(entry: .init(id: id, cover: cover, title: title), sourceId: runnerID)
            .dskBadge(badge)
    }
}

extension PageViewTile {
    struct TAG: View {
        let title: String
        let imageUrl: String?
        let runnerID: String
        @State var color: Color = .fadedPrimary
        @StateObject private var loader = FetchImage()

        var body: some View {
            ZStack(alignment: .bottom) {
                ZStack {
                    if let view = loader.image {
                        view
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 120)
                .background(Color.accentColor.opacity(0.80))
                .clipped()

                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.all, 2.5)
                    .frame(width: 150, height: 25, alignment: .center)
                    .background(color)
                    .foregroundColor(color.isDark ? .white : .black)
            }
            .frame(width: 150)
            .cornerRadius(7)
            .animation(.default, value: color)
            .animation(.default, value: loader.image)
            .animation(.default, value: loader.isLoading)
            .task {
                if loader.image != nil || loader.isLoading { return }
                loader.transaction = .init(animation: .easeInOut(duration: 0.25))
                loader.onCompletion = { result in
                    guard let result = try? result.get() else {
                        return
                    }

                    if let avgColor = result.image.averageColor {
                        color = Color(uiColor: avgColor)
                    }
                }

                if let str = imageUrl, let url = URL(string: str) {
                    loader.load(url)
                }
            }
        }
    }
}

// MARK: - Colored BadgeModifier

struct ColoredBadgeModifier: ViewModifier {
    let color: Color?
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            ColoredBadge(color: color ?? .sttDefault)
                .opacity(color != nil ? 1 : 0)
        }
    }
}

extension View {
    func coloredBadge(_ color: Color?) -> some View {
        modifier(ColoredBadgeModifier(color: color))
    }
}

struct CapsuleBadgeModifier: ViewModifier {
    let value: String
    let color: Color
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            CapsuleBadge(text: value, color: color)
        }
    }
}

struct DSKBadgeModifer: ViewModifier {
    let badge: DSKCommon.Badge?

    var color: Color {
        if let c = badge?.color {
            return Color(hex: c)
        } else {
            return .accentColor
        }
    }

    func body(content: Content) -> some View {
        if let badge {
            if let count = badge.count {
                content
                    .modifier(CapsuleBadgeModifier(value: count.clean, color: color))
            } else {
                content
                    .coloredBadge(color)
            }
        } else {
            content
        }
    }
}

extension View {
    func dskBadge(_ badge: DSKCommon.Badge?) -> some View {
        modifier(DSKBadgeModifer(badge: badge))
    }
}
