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

    var body: some View {
        Group {
            if let systemName = systemName {
                Image(systemName: systemName)
                    .resizable()
            } else if let url = url {
                LazyImage(url: url, resizingMode: .aspectFill)
                    .processors([.resize(size: .init(width: 44, height: 44))])
                    .onFailure { _ in
                        print("failing")
                        self.url = nil
                    }

            } else {
                Image(assetName ?? "stt_icon")
                    .resizable()
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
