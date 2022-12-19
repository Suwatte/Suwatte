//
//  History+ExternalChapters.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import RealmSwift
import SwiftUI

extension HistoryView {
    struct ExternalView: View {
        @ObservedResults(ChapterMarker.self) var unfilteredMarkers
        @State var selection: HighlightIndentier?
        var body: some View {
            let markers = getFiltered()
            ScrollView {
                LazyVStack {
                    ForEach(markers) { marker in
                        Tile(marker: marker, selection: $selection)
                            .modifier(HistoryView.ContextMenuModifier(marker: marker))
                            .padding(.vertical, 5)
                            .animation(.default, value: markers.contains(marker))
                            .id(marker.id)
                            .transition(HistoryView.transition)
                            
                    }
                }
                .padding()
            }
            .animation(.default, value: unfilteredMarkers)
            .animation(.default, value: markers)
            .navigationTitle("History")
            .modifier(InteractableContainer(selection: $selection))
        }

        private func getFiltered() -> Results<ChapterMarker> {
            return unfilteredMarkers.where { value in
                let timeAgo = Calendar.current.date(
                    byAdding: .month,
                    value: -3,
                    to: Date()
                )! // Three Months Back
                return value.chapter != nil &&
                    value.chapter.sourceId != STTHelpers.LOCAL_CONTENT_ID &&
                    value.chapter.sourceId != STTHelpers.OPDS_CONTENT_ID &&
                    value.dateRead != nil &&
                    value.dateRead >= timeAgo
            }
            .sorted(by: \.dateRead, ascending: false)
            .distinct(by: ["chapter.sourceId", "chapter.contentId"])
        }
    }
}

extension HistoryView.ExternalView {
    struct Tile: View {
        var marker: ChapterMarker
        var size = 140.0
        @Binding var selection: HighlightIndentier?

        var body: some View {
            if let entry = entry {
                ContentFound(entry)
                    .modifier(HistoryView.StyleModifier())
                    .onTapGesture {
                        let chapter = marker.chapter!
                        selection = (chapter.sourceId, .init(contentId: chapter.contentId, cover: entry.cover, title: entry.title))
                    }
            }
        }

        // Data
        var entry: StoredContent? {
            return DataManager.shared.getStoredContent(chapter.sourceId, chapter.contentId)
        }

        var chapter: StoredChapter {
            marker.chapter!
        }

        var identifier: ContentIdentifier {
            ContentIdentifier(contentId: chapter.contentId, sourceId: chapter.sourceId)
        }

        // Views
        func ImageView(imageUrl: String) -> some View {
            STTImageView(url: URL(string: imageUrl), identifier: identifier)
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .cornerRadius(5)
                .shadow(radius: 3)
        }

        @ViewBuilder
        func ContentFound(_ entry: StoredContent) -> some View {
            HStack {
                ImageView(imageUrl: entry.cover)

                VStack(alignment: .leading) {
                    Text(entry.title)
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

                HistoryView.ProgressIndicator(progress: marker.completed ? 1.0 : marker.progress)
            }
        }
    }
}

extension HistoryView {
    static var transition = AnyTransition.asymmetric(insertion: .slide, removal: .scale)

    struct ContextMenuModifier: ViewModifier {
        var marker: ChapterMarker
        func body(content: Content) -> some View {
            content
                .contextMenu {
                    Button(role: .destructive) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { // Wait for Context Menu Animation to finish
                            handleRemoveMarkers(marker)
                        }
                    } label: {
                        Label("Remove", systemImage: "eye.slash")
                    }
                }
        }

        private func handleRemoveMarkers(_ marker: ChapterMarker) {
            let realm = try! Realm()
            let targets = realm.objects(ChapterMarker.self).where {
                $0.chapter.contentId == marker.chapter!.contentId &&
                    $0.chapter.sourceId == marker.chapter!.sourceId
            }
            try! realm.safeWrite {
                realm.delete(targets)
            }
        }
    }
}
