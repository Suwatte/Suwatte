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
        Section {
            ForEach(entries) { content in
                let state = model.operations[content.id] ?? .idle
                MigrationEntryListCell(content: content, state: state)
            }
        } header: {
            Text("Titles")
        }
        .headerProminence(.increased)
    }
}

struct MigrationEntryListCell: View {
    let content: TaggedHighlight
    let state: MigrationItemState
    @EnvironmentObject private var model: MigrationController
    @AppStorage(STTKeys.TileStyle) private var tileStyle = TileStyle.SEPARATED

    var body: some View {
        VStack {
            // Warning
            HStack {
                Text(model.sources[content.sourceID]?.name ?? "")
                Spacer()
                Text("Destination")
            }
            .font(.subheadline.weight(.light))
            HStack(alignment: .center, spacing: 0) {
                let WIDTH: CGFloat = 150
                let HEIGHT: CGFloat = (WIDTH * 1.5) + tileStyle.titleHeight
                DefaultTile(entry: content.highlight, sourceId: content.sourceID)
                    .frame(width: WIDTH, height: HEIGHT)
                Spacer()
                Image(systemName: "chevron.right.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(state.color)
                    .frame(width: 15, height: 15)
                Spacer()
                MigrationEntryListResultCell(state: state, content: content)
                    .frame(width: WIDTH, height: HEIGHT, alignment: state == .noMatches ? .trailing : .center)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                model.removeItem(id: content.id)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: Result Cell

struct MigrationEntryListResultCell: View {
    let state: MigrationItemState
    let content: TaggedHighlight

    @EnvironmentObject private var model: MigrationController

    var body: some View {
        Group {
            switch state {
            case .idle, .searching:
                DefaultTile(entry: .placeholder)
                    .redacted(reason: .placeholder)
            case .noMatches:
                Button {
                    model.selectedToSearch = content
                } label: {
                    VStack(alignment: .trailing) {
                        Text("No Matches")
                        Text("Tap To Search")
                            .font(.callout)
                            .fontWeight(.light)
                    }
                }
                .buttonStyle(.plain)

            case let .found(entry), let .lowerFind(entry, _, _):
                DefaultTile(entry: entry.highlight, sourceId: entry.sourceID)
            }
        }
    }
}
