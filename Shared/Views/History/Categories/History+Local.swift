//
//  History+LocalContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import RealmSwift
import SwiftUI
import NukeUI

extension HistoryView {
    struct LocalContentTile: View {
        var marker: HistoryObject
        @StateObject private var imageView = FetchImage()

        var size = 140.0
        @EnvironmentObject var model: HistoryView.ViewModel
        var body: some View {
            if let id = Int64(marker.contentId), let book = LocalContentManager.shared.getBook(withId: id) {
                ContentFound(book)
                    .onTapGesture {
                        model.selectedBook = book
                    }
                    .modifier(StyleModifier())
            }
        }

        // Views
        @ViewBuilder
        func ContentFound(_ book: LocalContentManager.Book) -> some View {
            HStack {
                GeometryReader { proxy in
                    ZStack {
                        Rectangle().fill(Color.fadedPrimary)
                            .task {
                                imageView.priority = .normal
                                var request = book.getThumbnailRequest()
                                request?.processors = [NukeDownsampleProcessor(width: proxy.size.width)]
                                imageView.load(request)
                                imageView.transaction = .init(animation: .easeInOut(duration: 0.25))

                            }
                        imageView
                            .image?
                            .resizable()
                    }

                }
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .cornerRadius(7)
                .onDisappear {
                    imageView.reset()
                }

                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    Text("On My \(UIDevice.current.model)")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    Text(marker.dateRead!.timeAgo())
                        .font(.footnote)
                        .fontWeight(.light)
                        .foregroundColor(.gray)
                }

                Spacer()

                HistoryView.ProgressIndicator(progress: marker.progress)
            }
        }
    }
}
