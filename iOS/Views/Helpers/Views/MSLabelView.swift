//
//  MSLabelView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import NukeUI
import SwiftUI

struct MSLabelView: View {
    @State var title: String = ""
    @State var imageName: String = ""

    var body: some View {
        HStack(spacing: 15) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 32.0, height: 32.0)
                .cornerRadius(5)
            Text(title)
            Spacer()
        }
    }
}

struct STTThumbView: View {
    @State var assetName: String? = nil
    @State var systemName: String? = nil
    @State var url: URL? = nil
    @StateObject var imageFetcher = FetchImage()
    @Preference(\.accentColor) var color
    var body: some View {
        GeometryReader { proxy in
            Group {
                if let systemName = systemName {
                    Image(systemName: systemName)
                        .resizable()
                } else if url != nil {
                    if let image = imageFetcher.image {
                        image
                            .resizable()

                    } else {
                        Image(assetName ?? "stt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(color)
                            .padding(.all, 3)
                    }
                } else {
                    Image(assetName ?? "stt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color)
                        .padding(.all, 3)
                }
            }
            .task {
                guard let url = url else {
                    return
                }
                imageFetcher.priority = .normal
                imageFetcher.transaction = .init(animation: .easeInOut(duration: 0.33))
                imageFetcher.load(url)
                imageFetcher.processors = [NukeDownsampleProcessor(size: proxy.size)]
            }
            .onDisappear {
                imageFetcher.priority = .low
                imageFetcher.reset()
            }
        }
    }
}

struct STTLabelView: View {
    var title: String
    var label: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(label)
                .foregroundColor(.gray)
        }
    }
}

struct FieldLabel: View {
    var primary: String
    var secondary: String
    var body: some View {
        HStack {
            Text(primary)
            Spacer()
            Text(secondary)
                .fontWeight(.light)
                .foregroundColor(.primary.opacity(0.5))
        }
    }
}
