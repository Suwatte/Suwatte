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
    let badge: Color?
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
    @Environment(\.pageSectionStyle) var style
    
    
    var body: some View {
        Group {
            switch style {
            case .DEFAULT: NORMAL
            case .INFO: INFO
            case .GALLERY: GALLERY(runnerID: runnerID, id: id, title: title, subtitle: subtitle, cover: cover, additionalCovers: additionalCovers, info: info)
                    .coloredBadge(badge)
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
            }
        }
        .lineLimit(3)
        .multilineTextAlignment(.leading)
        .font(.subheadline.weight(.thin))
    }
}
// MARK: - DEFAULT

extension PageViewTile {
    var NORMAL: some View {
        DefaultTile(entry: .init(contentId: id, cover: cover, title: title), sourceId: runnerID)
            .coloredBadge(badge)
    }
}

extension PageViewTile{
    var LATEST: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: cover), identifier: .init(contentId: id, sourceId: runnerID))
                .frame(width: 95)
                .cornerRadius(5)
                .coloredBadge(badge)
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
        @State private var endColor = Color.black
        @State private var timer: Timer?
        @State private var currentImageIndex = 0
        private let prefetcher = ImagePrefetcher()
        private var foreGroundColor: Color {
            endColor.isDark ? .white : .black
        }
        
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
                Group {
                    if let view = loader.image {
                        GeometryReader { proxy in
                            view
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: proxy.size.width * 1.5, alignment: .center)
                                .transition(.opacity)
                        }
                        
                    } else {
                        Color.gray.opacity(0.25)
                    }
                }
                
                LinearGradient(gradient: Gradient(colors: [.clear, endColor]), startPoint: .center, endPoint: .bottom)
                VStack {
                    // Image Carasouel
                    Text(title)
                        .multilineTextAlignment(.center)
                        .font(.headline.weight(.semibold))
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
                        }
                    }
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .font(.footnote.weight(.thin))
                    
                    
                    if covers.count > 1 {
                        HStack {
                            ForEach(covers, id: \.self) { cover in
                                Rectangle()
                                    .frame(height: 3.5, alignment: .center)
                                    .foregroundColor(foreGroundColor.opacity((currentImageIndex == covers.firstIndex(of: cover)!) ? 1.0 : 0.25))
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .foregroundColor(foreGroundColor)
                
                .padding()
            }
            .animation(.default, value: currentImageIndex)
            .animation(.default, value: endColor)
            .onChange(of: currentImageIndex, perform: { _ in
                Task {
                    guard let url = urls.get(index: currentImageIndex) else { return }
                    await load(url: url)
                }
            })
            .cornerRadius(5)
            .onAppear(perform: didAppear)
            .onDisappear(perform: timer?.invalidate)
            .onAppear {
                prefetcher.startPrefetching(with: urls)
            }
            .onDisappear(perform: {
                prefetcher.stopPrefetching(with: urls)
            })
            .animation(.easeOut(duration: 0.25), value: loader.image)
            .animation(.easeOut(duration: 0.25), value: loader.isLoading)
        }
        
        func load(url: URL?) async {
            guard let url else { return }
            let runner = DSK.shared.getRunner(runnerID)
            
            guard let runner, runner.intents.imageRequestHandler, UserDefaults.standard.bool(forKey: STTKeys.RunnerOverridesImageRequest(runnerID)) else {
                loader.load(url)
                return
            }
            
            
            guard let response = try? await runner.willRequestImage(imageURL: url), let request = try? ImageRequest(urlRequest: response.toURLRequest()) else {
                loader.load(url)
                return
            }
            
            loader.load(request)
        }
        
        func didAppear() {
            // Update Loader
            loader.transaction = .init(animation: .easeInOut(duration: 0.25))
            loader.onCompletion = { response in
                guard let response = try? response.get() else {
                    return
                }
                if let color = response.image.averageColor {
                    endColor = Color(color)
                }
            }
            
            // Load First Image
            Task {
                await load(url: urls.first)
            }
            
            if urls.count == 1 {
                return
            }
            // Set Timer
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                withAnimation {
                    if covers.indices.contains(currentImageIndex + 1) {
                        currentImageIndex += 1
                    } else {
                        currentImageIndex = 0
                    }
                }
            }
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
                .coloredBadge(badge)
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
                .coloredBadge(badge)
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
        DefaultTile(entry: .init(contentId: id, cover: cover, title: title), sourceId: runnerID)
            .coloredBadge(badge)
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
                Group {
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
        ZStack(alignment: .topTrailing ) {
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
