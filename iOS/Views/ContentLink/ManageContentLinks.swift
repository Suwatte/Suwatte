//
//  ManageContentLinks.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-30.
//

import RealmSwift
import SwiftUI

struct ManageContentLinks: View {
    let id: String
    let highlight: DSKCommon.Highlight
    @State var presentAddSheet = false
    @State var linked: [StoredContent] = []
    @State var names: [String: String] = [:]
    var body: some View {
        List {
            ForEach(linked) { linked in
                NavigationLink {
                    ProfileView(entry: linked.toHighlight(), sourceId: linked.sourceId)
                } label: {
                    EntryCell(linked)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await unlink(linked) }
                    } label: {
                        Label("Unlink", systemImage: "pin.slash.fill")
                            .tint(.red)
                    }
                    .tint(.red)
                }
            }
        }
        .navigationTitle("Linked Titles")
        .toolbar {
            ToolbarItem {
                Button { presentAddSheet.toggle() } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $presentAddSheet, onDismiss: { Task { await fetch() }}) {
            NavigationView {
                AddContentLink(id: id, highlight: highlight)
                    .closeButton()
            }
        }
        .task {
            await fetch()
        }
    }

    func fetch() async {
        let actor = await RealmActor()
        let data = await actor.getLinkedContent(for: id)
        names = await actor.getAllRunnerNames()
        withAnimation {
            linked = data
        }
    }

    func unlink(_ title: StoredContent) async {
        let actor = await RealmActor()
        await actor.unlinkContent(title.id, id)
        await fetch()
    }

    @ViewBuilder
    func EntryCell(_ content: StoredContent) -> some View {
        HStack {
            STTImageView(url: URL(string: content.cover), identifier: content.ContentIdentifier)
                .frame(width: 75, height: 75 * 1.5, alignment: .center)
                .scaledToFit()
                .cornerRadius(5)
                .padding(.vertical, 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(content.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(3)
                Text(names[content.sourceId] ?? "")
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .frame(height: 75 * 1.5)
        .contentShape(Rectangle())
    }
}
