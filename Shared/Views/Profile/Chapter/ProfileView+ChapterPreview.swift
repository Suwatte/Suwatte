//
//  ProfileView+ChapterPreview.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-17.
//

import RealmSwift
import SwiftUI
extension ProfileView.Skeleton {
    struct ChapterView {}
}

private typealias CView = ProfileView.Skeleton.ChapterView

extension ProfileView.Skeleton.ChapterView {
    struct PreviewView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        var body: some View {
            HStack {
                Spacer()
                LoadableView(loadable: model.chapters,
                             { ProgressView().padding() },
                             { ProgressView().padding() },
                             { ErrorView(error: $0, action: {
                                 Task {
                                     await model.loadChapters()
                                 }
                             }) },
                             { chapters in
                                 if !chapters.isEmpty {
                                     LoadedView(chapters)
                                         .transition(.opacity)
                                 } else {
                                     LoadedEmptyView()
                                         .transition(.opacity)
                                 }
                             })
                Spacer()
            }
            .animation(.easeInOut(duration: 0.25), value: model.chapters)
        }

        @ViewBuilder
        func LoadedEmptyView() -> some View {
            VStack {
                Text("No Chapters Available")
                    .font(.headline.weight(.light))
                    .padding()
                Divider()
            }
        }

        @ViewBuilder
        func LoadedView(_ chapters: [StoredChapter]) -> some View {
            VStack(alignment: .center, spacing: 10) {
                HStack {
                    Text("\(chapters.count) \(chapters.count > 1 ? "Chapters" : "Chapter")")
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    LinkedUpdatesView()
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(preview(chapters)) { chapter in
                        let completed = isChapterCompleted(chapter)
                        let newChapter = isChapterNew(chapter)
                        let progress = chapterProgress(chapter)
                        let download = getDownload(chapter)
                        VStack(alignment: .leading, spacing: 2) {
                            ChapterListTile(chapter: chapter,
                                            isCompleted: completed,
                                            isNewChapter: newChapter,
                                            progress: progress,
                                            download: download)
                            if chapter.chapterId != preview(chapters).last?.chapterId {
                                Divider().padding(.top, 6)
                            }
                        }
                        .onTapGesture {
                            model.selection = chapter._id
                        }
                    }
                }
                .padding()
                .background(Color.fadedPrimary)
                .cornerRadius(12)

                VStack(alignment: .center) {
                    NavigationLink {
                        ChapterList()
                            .environmentObject(model)
                            .defaultAppStorage(.init(suiteName: model.sttIdentifier().id) ?? .standard)
                    } label: {
                        Text(chapters.count >= 5 ? "View All Chapters" : "Manage Chapters")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity)
                            .background(Color.fadedPrimary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Divider()
            }
        }

        func preview(_ chapters: [StoredChapter]) -> [StoredChapter] {
            chapters.count >= 5 ? Array(chapters[0 ... 4]) : Array(chapters[0...])
        }
    }
}

extension ProfileView.Skeleton.ChapterView.PreviewView {
    func isChapterCompleted(_ chapter: StoredChapter) -> Bool {
        model.readChapters.contains(chapter.number)
    }

    func isChapterNew(_ chapter: StoredChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: StoredChapter) -> Double? {
        guard let id = model.actionState.chapter?._id, id == chapter._id else {
            return nil
        }
        return model.actionState.marker?.progress
    }

    func getDownload(_ chapter: StoredChapter) -> ICDMDownloadObject? {
        model.downloads[chapter._id]
    }
}

struct LinkedUpdatesView: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    @State var selection: HighlightIndentier?
    var body: some View {
        let data = filtered()
        Menu {
            Text("Linked Titles Containing More Chapters")
            Divider()
            ForEach(data, id: \.entry.hashValue) { id in
                Button("\(id.entry.title) [\(SourceManager.shared.getSource(id: id.sourceId)!.name)]") {
                    selection = id
                }
            }
        } label: {
            ZStack {
                Image(systemName: "link.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                ColoredBadge(color: .blue, bodySize: 13, internalSize: 8)
            }
            .frame(height: 20)
        }
        .opacity(data.isEmpty ? 0 : 1)
        .modifier(InteractableContainer(selection: $selection))
    }

    func filtered() -> [HighlightIndentier] {
        model.linkedUpdates.filter { SourceManager.shared.getSource(id: $0.sourceId) != nil }
    }
}
