//
//  ExploreView+Tile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-30.
//

import Nuke
import NukeUI
import SwiftUI

extension ExploreView {
    struct HighlightTile: View {
        var entry: DaisukeEngine.Structs.Highlight
        var style: DSKCommon.CollectionStyle

        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED

        var sourceId: String
        var body: some View {
            Group {
                switch style {
                case .INFO: INFO
                case .NORMAL:
                    if tileStyle == .SEPARATED {
                        NORMAL_SEP
                            .transition(.opacity)
                    } else {
                        NORMAL_CPT
                            .transition(.opacity)
                    }
                case .GALLERY: GALLERY(entry: entry)
                case .UPDATE_LIST: LATEST
                }
            }
        }
    }
}

extension ExploreView.HighlightTile {
    var INFO: some View {
        return HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: entry.covers.first ?? ""), identifier: .init(contentId: entry.id, sourceId: sourceId))
                .frame(width: 100)
                .cornerRadius(7)
                .padding(.all, 5)
                .shadow(radius: 2.5)

            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let tags = entry.tags {
                    Text(tags.prefix(3).joined(separator: ", "))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .font(.subheadline.weight(.thin))
                }

                Spacer()
                VStack(alignment: .leading) {
                    if let views = entry.stats?.views, views != 0 {
                        Text("\(views) Views")
                    }
                    if let follows = entry.stats?.follows, follows != 0 {
                        Text("\(follows) Follows")
                    }

                    if let rating = entry.stats?.rating {
                        Text("\(rating.clean) \(Image(systemName: "star.fill"))")
                    }
                }
                .font(.subheadline.weight(.light))
                .opacity(0.55)
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
            Spacer()
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(7)
    }

    var NORMAL_CPT: some View {
        GeometryReader { reader in
            ZStack {
                STTImageView(url: URL(string: entry.covers.first ?? ""), identifier: .init(contentId: entry.id, sourceId: sourceId))
                    .cornerRadius(10)

                LinearGradient(gradient: Gradient(colors: [.clear, Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255)]), startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading) {
                    Spacer()
                    Text(entry.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .foregroundColor(Color.white)
                        .shadow(radius: 2)
                        .multilineTextAlignment(.leading)
                        .padding(.all, 5)
                }
                .frame(maxWidth: reader.size.width, alignment: .leading)
            }
            .cornerRadius(10)
        }
    }

    var NORMAL_SEP: some View {
        GeometryReader { reader in
            VStack(alignment: .leading, spacing: 5) {
                STTImageView(url: URL(string: entry.covers.first ?? ""), identifier: .init(contentId: entry.id, sourceId: sourceId))
                    .frame(height: reader.size.width * 1.5)
                    .cornerRadius(7)

                Text(entry.title)
                    .font(.subheadline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    var LATEST: some View {
        HStack(alignment: .top, spacing: 5) {
            // Image
            STTImageView(url: URL(string: entry.covers.first ?? ""), identifier: .init(contentId: entry.id, sourceId: sourceId))
                .frame(width: 100)
                .cornerRadius(7)
                .padding(.all, 7)
                .shadow(radius: 2.5)

            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let chapter = entry.chapter {
                    Text("\(chapter.label) • \(chapter.date.timeAgo())")
                        .font(.headline)
                        .fontWeight(.light)
                    Text("\(chapter.badge) Update\(chapter.badge > 1 ? "s" : "")")
                        .font(.subheadline)
                        .fontWeight(.light)
                }
            }
            .padding(.vertical, 7)
            .padding(.trailing, 5)
            Spacer()
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(7)
    }

    struct GALLERY: View {
        var entry: DaisukeEngine.Structs.Highlight
        @State var endColor = Color.black
        @State var timer: Timer?
        @State var currentImageIndex = 0
        let prefetcher = ImagePrefetcher()
        var foreGroundColor: Color {
            endColor.isDark ? .white : .black
        }

        var urls: [URL] {
            entry.covers.compactMap { URL(string: $0) }
        }

        var body: some View {
            ZStack(alignment: .bottom) {
                LazyImage(url: URL(string: entry.covers.get(index: currentImageIndex) ?? ""), resizingMode: .aspectFill)
                    .onSuccess { response in
                        if let color = response.image.averageColor {
                            endColor = Color(color)
                        }
                    }
                    .animation(.default)
                    .onAppear {
                        prefetcher.startPrefetching(with: urls)
                    }
                    .onDisappear(perform: {
                        prefetcher.stopPrefetching(with: urls)
                    })

                    .background(Color.sttGray)

                LinearGradient(gradient: Gradient(colors: [.clear, endColor]), startPoint: .center, endPoint: .bottom)
                VStack {
                    // Image Carasouel
                    Text(entry.title)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .font(.title3.weight(.bold))
                    if let subtilte = entry.subtitle {
                        Text(subtilte)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                            .font(.subheadline.weight(.semibold))
                    }

                    if let tags = entry.tags {
                        Text(tags.prefix(3).joined(separator: ", "))
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                            .font(.subheadline.weight(.light))
                    }

                    if entry.covers.count > 1 {
                        HStack {
                            ForEach(entry.covers, id: \.self) { cover in

                                Rectangle()
                                    .frame(height: 3.5, alignment: .center)
                                    .foregroundColor(foreGroundColor.opacity((currentImageIndex == entry.covers.firstIndex(of: cover)!) ? 1.0 : 0.25))
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
            .cornerRadius(7)

//            .onAppear {
//                timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
//                    withAnimation {
//                        if entry.covers.indices.contains(currentImageIndex + 1) {
//                            currentImageIndex += 1
//                        } else {
//                            currentImageIndex = 0
//                        }
//                    }
//                }
//            }
//            .onDisappear {
//                timer?.invalidate()
//            }
        }
    }
}
