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
            VStack {
                LinkChaptersSection(model: model)

                let chapters = model.getPreviewChapters(for: model.getCurrentStatement())
                switch model.chapterState {
                case .loaded:
                    if !chapters.isEmpty {
                        LoadedView(chapters)
                            .transition(.opacity)
                    } else {
                        LoadedEmptyView()
                            .transition(.opacity)
                    }
                case let .failed(error):
                    ErrorView(error: error, action: {
                        await model.loadChapters()
                    })
                    .transition(.opacity)
                default:
                    LoadedView(ThreadSafeChapter.placeholders(count: 6), redacted: true)
                        .redacted(reason: .placeholder)
                        .shimmering()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.currentChapterSection)
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
        func LoadedView(_ chapters: [ThreadSafeChapter], redacted: Bool = false) -> some View {
            let statement = model.getCurrentStatement()
            let filteredOut = statement.originalList.count - statement.filtered.count
            VStack(alignment: .center, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("^[\(statement.distinctCount) Chapter](inflect: true)")
                            .font(.title3)
                            .fontWeight(.bold)

                        // Viewing Linked entry
                        if model.currentChapterSection != model.identifier {
                            let statement = model.getCurrentStatement()
                            Text("\(Image(systemName: "link")) \(statement.content.contentName)")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }

                        if filteredOut != 0 {
                            Text("^[\(filteredOut) chapter](inflect: true) hidden.")
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(chapters) { chapter in
                        let completed = isChapterCompleted(chapter)
                        let newChapter = isChapterNew(chapter)
                        let progress = chapterProgress(chapter)
                        let download = getDownload(chapter)
                        VStack(alignment: .leading, spacing: 2) {
                            ChapterListTile(chapter: chapter,
                                            isCompleted: completed,
                                            isNewChapter: newChapter,
                                            progress: progress,
                                            download: download,
                                            isLinked: chapter.sourceId != model.source.id,
                                            showLanguageFlag: model.source.ablityNotDisabled(\.disableLanguageFlags),
                                            showDate: model.source.ablityNotDisabled(\.disableChapterDates),
                                            isBookmarked: model.bookmarkedChapters.contains(chapter.id))
                            if chapter.chapterId != chapters.last?.chapterId {
                                Divider().padding(.top, 6)
                            }
                        }
                        .onTapGesture {
                            guard !redacted else { return }

                            if model.content.contentType == .novel {
                                StateManager.shared.alert(title: "Novel Reading", message: "Novel reading is currently not supported until version 6.1")
                                return
                            }
                            model.selection = chapter
                        }
                    }
                }
                .padding()
                .background(Color.fadedPrimary)
                .cornerRadius(12)
                .animation(.default, value: model.bookmarkedChapters)

                VStack(alignment: .center) {
                    NavigationLink {
                        ChapterList(model: model)
                    } label: {
                        Text(chapters.count >= 5 ? "View All Chapters" : "Manage Chapters")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.vertical, 12.5)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(redacted)
                }

                Divider()
            }
        }
    }
}

extension ProfileView.Skeleton.ChapterView.PreviewView {
    func isChapterCompleted(_ chapter: ThreadSafeChapter) -> Bool {
        guard let marker = model.readChapters[chapter.STTContentIdentifier]?[chapter.id] else {
            return false
        }

        return marker.isCompleted
    }

    func isChapterNew(_ chapter: ThreadSafeChapter) -> Bool {
        guard let date = model.actionState.marker?.date else {
            return false
        }
        return chapter.date > date
    }

    func chapterProgress(_ chapter: ThreadSafeChapter) -> Double? {
        guard let marker = model.readChapters[chapter.STTContentIdentifier]?[chapter.id] else {
            return nil
        }

        return marker.progress
    }

    func getDownload(_ chapter: ThreadSafeChapter) -> DownloadStatus? {
        model.downloads[chapter.id]
    }
}

extension ProfileView.Skeleton.ChapterView.PreviewView {
    struct LinkChaptersSection: View {
        @ObservedObject var model: ProfileView.ViewModel

        private var count: Int {
            model.chapterMap.count
        }

        private var entryStatement: ChapterStatement? {
            model.chapterMap[model.identifier]
        }

        var body: some View {
            if count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        if let entryStatement {
                            Cell(statement: entryStatement)
                        }

                        ForEach(model.chapterMap.sorted(by: \.value.index, descending: false), id: \.key) { key, value in
                            if key == model.identifier {
                                EmptyView()
                            } else {
                                Cell(statement: value)
                            }
                        }
                    }
                    .padding([.top, .bottom], 4)
                }
            }
        }

        @ViewBuilder
        func Cell(statement: ChapterStatement) -> some View {
            if model.currentChapterSection == statement.content.contentIdentifier.id {
                Button(statement.content.runnerName) {}
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
            } else {
                Button(statement.content.runnerName) {
                    model.chapterState = .loading
                    model.currentChapterSection = statement.content.contentIdentifier.id

                    Task {
                        await model.loadLinkedChapters()
                        await model.setActionState()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .coloredBadge(statement.maxOrderKey > (entryStatement?.maxOrderKey ?? 0) ? .blue : nil)
            }
        }
    }
}
