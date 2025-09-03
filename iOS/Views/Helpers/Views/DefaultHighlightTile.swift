//
//  DefaultHighlightTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import SwiftUI

struct DefaultTile: View {
    var entry: DaisukeEngine.Structs.Highlight
    var sourceId: String?
    @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
    @Environment(\.libraryIsSelecting) var libraryIsSelecting
    var body: some View {
        GeometryReader { reader in
            ZStack {
                switch tileStyle {
                case .COMPACT:
                    CompactStyle(reader: reader)
                case .SEPARATED:
                    SeparatedStyle(reader: reader)
                }
            }
        }
    }

    var ImageV: some View {
        STTImageView(url: URL(string: entry.cover), identifier: .init(contentId: entry.id, sourceId: sourceId ?? ""))
    }

    func CompactStyle(reader: GeometryProxy) -> some View {
        ZStack {
            ImageV
                .opacity(libraryIsSelecting ? 0.8 : 1)

            if reader.size.width >= 100 {
                LinearGradient(gradient: Gradient(colors: [.clear, Color(red: 15 / 255, green: 15 / 255, blue: 15 / 255).opacity(0.90)]), startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading) {
                    Spacer()
                    Text(entry.title)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(Color.white)
                    if let subtitle = entry.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .shadow(radius: 3)
                .multilineTextAlignment(.leading)
                .padding(.all, 7)
                .frame(width: reader.size.width, alignment: .leading)
            }
        }
        .cornerRadius(5)
    }

    func SeparatedStyle(reader: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ImageV
                .frame(height: reader.size.width * 1.5)
                .cornerRadius(4.5)
                .opacity(libraryIsSelecting ? 0.8 : 1)

            if reader.size.width >= 100 {
                Text(entry.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.primary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true) // Allows the subtitle to occupy the remaining vertical space
                }
            }
        }
        .multilineTextAlignment(.leading)
    }
}
