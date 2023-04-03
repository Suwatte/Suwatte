//
//  ManageContentLinks.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-30.
//

import RealmSwift
import SwiftUI

struct ManageContentLinks: View {
    @ObservedResults(ContentLink.self) var entries
    var content: StoredContent
    @State var presentAddSheet = false

    init(content: StoredContent) {
        self.content = content
        let id = content._id
        $entries.where = { $0.ids.contains(id) }
    }

    var body: some View {
        let data = fetch()
        List {
            ForEach(data) { linked in
                NavigationLink {
                    ProfileView(entry: linked.toHighlight(), sourceId: linked.sourceId)
                } label: {
                    EntryCell(linked)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading) {
                    Button(role: .destructive) {
                        DataManager.shared.unlinkContent(linked, content)
                    } label: {
                        Label("Unlink", systemImage: "pin.slash.fill")
                            .tint(.red)
                    }
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
        .sheet(isPresented: $presentAddSheet, content: {
            NavigationView {
                AddContentLink(content: content)
                    .closeButton()
            }
        })
    }

    func fetch() -> [StoredContent] {
        DataManager.shared.getLinkedContent(for: content._id)
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
                Text(content.SourceName)
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .frame(height: 75 * 1.5)
        .contentShape(Rectangle())
    }
}
