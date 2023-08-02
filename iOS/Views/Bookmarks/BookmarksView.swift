//
//  BookmarksView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import RealmSwift
import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject private var profileModel: ProfileView.ViewModel
    @StateObject private var model: ViewModel = .init()
    typealias SectionGroup = SectionedResults<String, Bookmark>

    @State var pageIndex: Int?
    @State var selectedChapter: StoredChapter?

    var body: some View {
        NavigationView {
            Group {
                if let results = model.results {
                    if results.isEmpty {
                        EmptyResultsView()
                    } else {
                        ResultsView(results)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Bookmarks")
            .closeButton()
            .task {
                observe()
            }
            .onDisappear(perform: stop)
            .fullScreenCover(item: $selectedChapter, onDismiss: observe) { chapter in
                let chapters = profileModel.chapters.value ?? [chapter]
                ReaderGateWay(readingMode: profileModel.content.recommendedReadingMode ?? .defaultPanelMode,
                              chapterList: chapters,
                              openTo: chapter,
                              pageIndex: pageIndex)
                    .onAppear(perform: stop)
            }
        }
    }

    func observe() {
        Task {
            await model.observe(id: profileModel.sttIdentifier().id)
        }
    }
    
    func stop() {
        Task {
            await model.stop()
        }
    }

    func EmptyResultsView() -> some View {
        VStack(alignment: .center, spacing: 7) {
            Text("(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧")
                .font(.title3)

            Text("No Bookmarks")
                .font(.headline)
                .fontWeight(.light)

            Text("Long press a page in the reader to add a bookmark!")
                .font(.subheadline)
                .fontWeight(.thin)
        }
    }

    @ViewBuilder
    func ResultsView(_ results: SectionGroup) -> some View {
        List {
            ForEach(results) { data in
                ChapterSectionView(section: data, pageIndex: $pageIndex, selectedChapter: $selectedChapter)
            }
        }
        .headerProminence(.increased)
    }

}

// MARK: ChapterSectionView
extension BookmarksView {
    struct ChapterSectionView: View {
        let section: SectionGroup.Element
        @Binding var pageIndex: Int?
        @Binding var selectedChapter: StoredChapter?
        @State var images: [String] = []
        @EnvironmentObject private var profileModel: ProfileView.ViewModel
        var body: some View {
            Group {
                if let chapter = section.first?.chapter {
                    Section {
                        ForEach(section) { bookmark in
                            Cell(bookmark: bookmark, chapter: chapter, imageUrl: images.get(index: bookmark.page))
                        }
                    } header: {
                        Text(chapter.displayName)
                    }
                } else {
                    EmptyView()
                }
            }
            .task {
                await loadImages()
            }
        }
        
        func loadImages() async {
            guard images.isEmpty, let id = section.first?.chapter?.id else { return }
            let actor = await RealmActor()
            let data = await actor.getChapterData(forId: id)?.imageURLs ?? []
            Task { @MainActor in
                images = data
            }
        }

        @ViewBuilder
        func Cell(bookmark: Bookmark, chapter: ChapterReference, imageUrl: String?) -> some View {
            HStack {
                BaseImageView(url: URL(string: imageUrl ?? ""), runnerId: chapter.content?.sourceId)
                    .frame(width: 120, height: 120 * 1.5, alignment: .center)
                    .cornerRadius(5)
                Spacer()
                VStack(alignment: .trailing) {
                    Spacer()
                    Text("Page \(bookmark.page + 1)")
                    Text("Added \(bookmark.dateAdded.timeAgoGrouped())")
                }
                .font(.footnote.weight(.light))
                .foregroundColor(.gray)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Update marker to Page
                pageIndex = bookmark.page
                // Open reader
                selectedChapter = (profileModel.chapters.value ?? []).first(where: { $0.chapterId == chapter.chapterId })
            }
            .swipeActions(allowsFullSwipe: true) {
                Button {
                    Task {
                        let actor = await RealmActor()
                        await actor.removeBookmark(bookmark.id)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }
}

// MARK: ViewModel

extension BookmarksView {
    final actor ViewModel: ObservableObject {
        private var token: NotificationToken?
        @MainActor @Published var results: SectionedResults<String, Bookmark>?

        func observe(id: String) async {
            let realm = try! await Realm(actor: self)
            let results = realm
                .objects(Bookmark.self)
                .where { !$0.isDeleted }
                .where { $0.chapter != nil && $0.chapter.content != nil }
                .where { $0.chapter.content.id == id }
                .sectioned(by: \.chapter!.id, sortDescriptors: [.init(keyPath: "chapter.id"), .init(keyPath: "page")])

            token = await results.observe(on: self, { _, results in
                switch results {
                case .initial(let initialData):
                    let frozen = initialData.freeze()
                    Task { @MainActor in
                        withAnimation {
                            self.results = frozen
                        }
                    }
                    break
                case .update(let updatedData, _, _, _, _, _):
                    let frozen = updatedData.freeze()
                    Task { @MainActor in
                        withAnimation {
                            self.results = frozen
                        }
                    }
                    break
                }
            })
        }

        func stop() {
            token?.invalidate()
            token = nil
        }
    }
}
