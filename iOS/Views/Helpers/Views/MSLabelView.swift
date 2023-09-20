//
//  MSLabelView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import NukeUI
import SwiftUI

struct MSLabelView: View {
    let title: String = ""
    let imageName: String = ""

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
    var assetName: String? = nil
    var systemName: String? = nil
    var url: URL? = nil
    @StateObject var imageFetcher = FetchImage()
    @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
    var body: some View {
        GeometryReader { proxy in
            ZStack {
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
                guard imageFetcher.image == nil else { return }
                imageFetcher.processors = [NukeDownsampleProcessor(size: proxy.size, scale: UIScreen.main.scale)]
                load()
            }
            .onDisappear {
                imageFetcher.priority = .low
                imageFetcher.reset()
            }
        }
    }
    
    private func load() {
        guard let url = url else {
            return
        }
        imageFetcher.priority = .normal
        imageFetcher.transaction = .init(animation: .easeInOut(duration: 0.33))
        imageFetcher.load(url)
    }
}

struct STTLabelView: View {
    let title: String
    let label: String

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
    let primary: String
    let secondary: String
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
