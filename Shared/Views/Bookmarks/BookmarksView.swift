//
//  BookmarksView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import RealmSwift
import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    @ObservedResults(Bookmark.self) var bookmarks
    @State var selectedChapter: StoredChapter?
    @State var openToIndex: Int?
    init() {
        // Filter Bookmarks
        $bookmarks.sortDescriptor = SortDescriptor(keyPath: "dateAdded", ascending: false)
    }

    var body: some View {
        NavigationView {
//            List(SortedIdentifiers) { marker in
//                let bookmarks = GroupedByMarker[marker]!
//                let images = DataManager.shared.getChapterData(forId: marker._id)?.imageURLs
//                Section {
//                    ForEach(bookmarks) { bookmark in
//                        let imageUrl = images?.get(index: bookmark.page) ?? ""
//                        Cell(bookmark: bookmark, marker: marker, url: imageUrl)
//                    }
//                } header: {
//                    Text(marker.chapter!.displayName)
//                }
//            }
//            .navigationTitle("Bookmarks")
//            .closeButton()
//            .fullScreenCover(item: $selectedChapter) { chapter in
//                let chapters = model.chapters.value ?? [chapter]
//                ReaderGateWay(readingMode: model.content.recommendedReadingMode ?? .PAGED_COMIC, chapterList: chapters, openTo: chapter, pageIndex: openToIndex)
//            }
//            .animation(.default, value: bookmarks)
        }
    }

//    func Cell(bookmark: Bookmark, marker: ChapterMarker, url: String) -> some View {
//        HStack {
//            BaseImageView(url: URL(string: url), sourceId: marker.chapter!.sourceId, mode: .fit)
//                .frame(width: 120, height: 120 * 1.5, alignment: .center)
//                .cornerRadius(7)
//
//            Spacer()
//            VStack(alignment: .trailing) {
//                Spacer()
//                Text("Page \(bookmark.page + 1)")
//                Text("Added \(bookmark.dateAdded.timeAgoGrouped())")
//            }
//            .font(.headline.weight(.light))
//            .foregroundColor(.gray)
//        }
//        .contentShape(Rectangle())
//        .onTapGesture {
//            // Update marker to Page
//            openToIndex = bookmark.page
//            // Open reader
//            selectedChapter = marker.chapter!
//        }
//        .swipeActions(allowsFullSwipe: true) {
//            Button {
//                DataManager.shared.toggleBookmark(chapter: marker.chapter!, page: bookmark.page)
//            } label: {
//                Label("Remove", systemImage: "trash")
//            }
//            .tint(.red)
//        }
//    }
//
//    var GroupedByMarker: [ChapterMarker: [Bookmark]] {
//        Dictionary(grouping: targets(), by: { $0.marker! })
//    }
//
//    func targets() -> Results<Bookmark> {
//        bookmarks
//            .where { $0.marker != nil }
//            .where { $0.marker.chapter != nil }
//            .where { $0.marker.chapter.sourceId == model.source.id }
//            .where { $0.marker.chapter.contentId == model.content.contentId }
//    }
//
//    var SortedIdentifiers: [ChapterMarker] {
//        let dictionary = GroupedByMarker
//        return Array(dictionary.keys.sorted(by: { $0.chapter!.number > $1.chapter!.number }))
//    }
}
