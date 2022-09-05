//
//  History+LocalContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import Kingfisher
import RealmSwift
import SwiftUI

extension HistoryView {
    struct LocalView: View {
        @ObservedResults(ChapterMarker.self) var unfilteredMarkers
        var body: some View {
            let markers = getFiltered()
            ScrollView {
                LazyVStack {
                    ForEach(markers) { marker in
                        Tile(marker: marker)
                            .modifier(HistoryView.ContextMenuModifier(marker: marker))
                            .padding(.vertical, 5)
                            .animation(.default, value: markers.contains(marker))
                            .id(marker.id)
                            .transition(HistoryView.transition)
                    }
                }
                .padding()
            }
            .animation(.default, value: markers)
            .navigationTitle("History")
        }

        private func getFiltered() -> Results<ChapterMarker> {
            return unfilteredMarkers.where { value in
                let timeAgo = Calendar.current.date(
                    byAdding: .month,
                    value: -3,
                    to: Date()
                )! // Three Months Back
                return value.chapter != nil &&
                    value.chapter.sourceId == STTHelpers.LOCAL_CONTENT_ID &&
                    value.dateRead != nil &&
                    value.dateRead >= timeAgo
            }
            .sorted(by: \.dateRead, ascending: false)
            .distinct(by: ["chapter.sourceId", "chapter.contentId"])
        }
    }
}

extension HistoryView.LocalView {
    struct Tile: View {
        var marker: ChapterMarker
        var size = 140.0
        @State var selection: LocalContentManager.Book?

        var body: some View {
            if let id = Int64(chapter.contentId), let book = LocalContentManager.shared.getBook(withId: id) {
                ContentFound(book)
                    .modifier(HistoryView.StyleModifier())
                    .onTapGesture {
                        selection = book
                    }
                    .fullScreenCover(item: $selection) { entry in
                        let chapter = LocalContentManager.shared.generateStored(for: entry)
                        ReaderGateWay(readingMode: entry.type == .comic ? .PAGED_COMIC : .NOVEL, chapterList: [chapter], openTo: chapter, title: entry.title)
                    }
            }
        }

        // Data
        var chapter: StoredChapter {
            marker.chapter!
        }

        // Views
        @ViewBuilder
        func ContentFound(_ book: LocalContentManager.Book) -> some View {
            HStack {
                GeometryReader { proxy in
                    KFImage.source(book.getImageSource())
                        .diskCacheExpiration(.expired)
                        .downsampling(size: proxy.size)
                        .fade(duration: 0.30)
                        .resizable()
                }
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .background(Color.fadedPrimary)
                .cornerRadius(7)

                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    Text(chapter.displayName)
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
