//
//  MigrationView+EntriesList.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-27.
//

import SwiftUI

struct MigrationEntryListView: View {
    @EnvironmentObject private var model: MigrationController

    private var entries: [TaggedHighlight] {
        model.contents
    }

    var body: some View {
        // TODO: Update styling when UIKit is replacing this view
        ForEach(entries) { content in
            let state = model.operations[content.id] ?? .idle
            MigrationEntryListCell(content: content, state: state)
                .padding(.top, 10)
                .id(content.id + (state.value()?.0?.id ?? ""))
        }
    }
}

struct MigrationEntryListCell: View {
    let content: TaggedHighlight
    let state: MigrationItemState
    @State var chapterCount: Int = 0
    @EnvironmentObject private var model: MigrationController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MigrationTile(highlight: content.highlight, sourceId: content.sourceID, chapterCount: chapterCount)
                .onAppear {
                    Task {
                        chapterCount = await model.getStoredChapterCount(for: content)
                    }
                }
            HStack {
                Spacer()
                Image(systemName: "chevron.down.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(state.color)
                    .frame(width: 15, height: 15)
                Spacer()
            }
            .padding(.vertical, 3)
            MigrationEntryListResultCell(state: state, content: content)
        }
        .swipeActions {
            Button(role: .destructive) {
                model.removeItem(id: content.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

struct MigrationTile: View {
    var highlight: DaisukeEngine.Structs.Highlight
    var sourceId: String?
    var chapterCount: Int?

    @EnvironmentObject private var model: MigrationController

    var body: some View {
        let WIDTH: CGFloat = 50
        let HEIGHT: CGFloat = (WIDTH * 1.5)

        HStack(alignment: .top) {
            STTImageView(url: URL(string: highlight.cover), identifier: .init(contentId: highlight.id, sourceId: sourceId ?? ""))
                .frame(minWidth: 0, idealWidth: WIDTH, maxWidth: WIDTH, minHeight: 0, idealHeight: HEIGHT, maxHeight: HEIGHT, alignment: .leading)
                .scaledToFit()
                .cornerRadius(5)
                .shadow(radius: 3)

            let sourceName = sourceId != nil ? model.sources[sourceId!]?.name ?? sourceId! : ""

            VStack(alignment: .leading, spacing: 2.5) {
                Text(sourceName)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray)
                Text(highlight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                if let chapterCount = chapterCount {
                    Text("\(chapterCount) Chapters")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 0, idealHeight: HEIGHT, maxHeight: HEIGHT, alignment: .topLeading)
        }
    }
}


// MARK: Result Cell

struct MigrationEntryListResultCell: View {
    let state: MigrationItemState
    let content: TaggedHighlight

    @EnvironmentObject private var model: MigrationController

    var body: some View {
        Button {
            model.selectedToSearch = content
        } label: {
            HStack {
                switch state {
                    case .idle, .searching:
                        MigrationTile(highlight: .placeholder)
                            .redacted(reason: .placeholder)
                    case .noMatches:
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.horizontal, 15)
                            .foregroundColor(.accentColor)
                        Text("No matches! Tap To Search")
                            .font(.footnote)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)


                    case let .found(entry, chapterCount), let .lowerFind(entry, _, _, chapterCount):
                        MigrationTile(highlight: entry.highlight, sourceId: entry.sourceID, chapterCount: chapterCount)
                }

                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(.gray)
            }
            .padding(.top, state == .noMatches ? 10 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
