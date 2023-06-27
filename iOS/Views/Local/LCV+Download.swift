//
//  LCV+Download.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-07.
//

import SwiftUI

struct LCV_Download: View {
    @StateObject var manager: LocalContentManager = .shared
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(manager.downloads, id: \.url) { download in
                        Tile(download: download)
                            .swipeActions {
                                Button(role: .destructive) {
                                    manager.removeFromQueue(download)
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Local Downloads")
            .closeButton()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Cancel All", role: .destructive) {
                            manager.downloads.forEach { manager.removeFromQueue($0) }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    struct Tile: View {
        @ObservedObject var download: LocalContentManager.DownloadObject

        let size = CGFloat(80)
        var body: some View {
            HStack {
                GeometryReader { _ in
                    AsyncImage(url: URL(string: download.cover))
                }
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .background(Color.fadedPrimary)
                .cornerRadius(5)

                VStack {
                    Text(download.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                Spacer()
//                HistoryView.ProgressIndicator(progress: download.progress)
            }
        }
    }
}
