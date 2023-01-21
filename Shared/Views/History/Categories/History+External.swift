//
//  History+ExternalChapters.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import RealmSwift
import SwiftUI


extension HistoryView {
    struct ExternalContentTile: View {
        @EnvironmentObject var model: HistoryView.ViewModel
        var marker: HistoryObject
        @State var excerpt: DSKCommon.Highlight?
        @State var loaded: Bool = false
        var size = 140.0
        var body: some View {
            Group {
                if let excerpt {
                    ContentFound(excerpt)
                } else {
                    if loaded {
                        EmptyView()
                    } else {
                        ProgressView()
                    }
                }
            }
            .modifier(StyleModifier())
            .onTapGesture {
                guard let excerpt else { return }
                model.selection = (marker.sourceId, excerpt)
            }
            .task {
                if excerpt != nil { return }
                let data = DataManager.shared.getStoredContent(marker.sourceId, marker.contentId)
                excerpt = data?.toHighlight()
                loaded = true
            }
        }
        var identifier: ContentIdentifier {
            ContentIdentifier(contentId: marker.contentId, sourceId: marker.sourceId)
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
        func ContentFound(_ entry: DSKCommon.Highlight) -> some View {
            HStack {
                ImageView(imageUrl: entry.cover)

                VStack(alignment: .leading) {
                    Text(entry.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)

                    Text(marker.chapterName)
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

    struct DeleteModifier: ViewModifier {
        var marker: HistoryObject
        func body(content: Content) -> some View {
            content
                .swipeActions(allowsFullSwipe: true, content: {
                    Button(role: .destructive) {
                        handleRemoveMarkers(marker)
                    } label: {
                        Label("Remove", systemImage: "eye.slash")
                    }
                    .tint(.red)
                })
        }

        private func handleRemoveMarkers(_ marker: HistoryObject) {
            let realm = try! Realm()
            
            let targets = realm.objects(ChapterMarker.self).where {
                $0.chapter.contentId == marker.contentId &&
                    $0.chapter.sourceId == marker.sourceId
            }
            realm.writeAsync {
                realm.delete(targets)
            }
        }
    }
}
