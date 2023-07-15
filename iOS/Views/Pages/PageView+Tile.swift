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
        var entry: DSKCommon.PageSectionItem
        var runnerID: String
        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
        @Environment(\.pageSectionStyle) var style
        
        var title: String {
            entry.title ?? entry.label ?? ""
        }
        
        /// Only Used in imageview
        var id: String {
            entry.id ?? ""
        }
        
        var body: some View {
            Group {
                switch style {
                case .INFO: INFO
                case .NORMAL: NORMAL
                case .GALLERY: GALLERY(entry: entry, runnerID: runnerID)
                case .UPDATE_LIST: LATEST
                case .TAG: EmptyView()
                }
            }
        }
    }


// MARK: - Info Style Tile
extension PageViewTile {
    var INFO: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: entry.cover ?? ""), identifier: .init(contentId: id, sourceId: runnerID))
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
            ForEach(entry.info ?? []) {
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
        Group {
            if tileStyle == .SEPARATED {
                   NORMAL_SEP
                       .transition(.opacity)
               } else {
                   NORMAL_CPT
                       .transition(.opacity)
               }
        }
    }
    var NORMAL_CPT: some View {
        GeometryReader { reader in
            ZStack {
                STTImageView(url: URL(string: entry.cover ?? ""), identifier: .init(contentId: id, sourceId: runnerID))
                    .cornerRadius(10)
                
                LinearGradient(gradient: Gradient(colors: [.clear, Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255).opacity(0.8)]), startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading) {
                    Spacer()
                    Text(title)
                        .font(.footnote)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(Color.white)
                        .shadow(radius: 2)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 7)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: reader.size.width, alignment: .leading)
            }
            .cornerRadius(10)
        }
    }
    
    var NORMAL_SEP: some View {
        GeometryReader { reader in
            VStack(alignment: .leading, spacing: 5) {
                STTImageView(url: URL(string: entry.cover ?? ""), identifier: .init(contentId: id, sourceId: runnerID))
                    .frame(height: reader.size.width * 1.5)
                    .cornerRadius(5)
                
                Text(title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

extension PageViewTile{
        var LATEST: some View {
            HStack(alignment: .top, spacing: 5) {
                // Image
                STTImageView(url: URL(string: entry.cover ?? ""), identifier: .init(contentId: id, sourceId: runnerID))
                    .frame(width: 100)
                    .cornerRadius(5)
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
        var entry: DSKCommon.PageSectionItem
            var runnerID: String
            @State private var endColor = Color.black
            @State private var timer: Timer?
            @State private var currentImageIndex = 0
            private let prefetcher = ImagePrefetcher()
            private var foreGroundColor: Color {
                endColor.isDark ? .white : .black
            }
        
        var covers: [String] {
            Array(
                Set([cover] + (entry.additionalCovers ?? []))
            )
        }
        var cover: String {
            entry.cover ?? ""
        }
    
            @StateObject private var loader = FetchImage()
            var urls: [URL] {
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
                        Text(entry.title ?? entry.label ?? "")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .font(.title3.weight(.bold))

                        VStack(alignment: .leading) {
                            ForEach(entry.info ?? []) {
                                Text($0)
                            }
                        }
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline.weight(.thin))
                        
    
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
