//
//  History+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import SwiftUI
import RealmSwift

extension HistoryView {
    struct OPDSContentTile: View {
        @EnvironmentObject var model: HistoryView.ViewModel
        var marker: HistoryObject
        var size = 140.0
        var body: some View {
            HStack {
                ImageView(imageUrl: marker.thumbnail ?? "")

                VStack(alignment: .leading) {
                    Text(marker.chapterName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)

                    Text("OPDS")
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
            .modifier(StyleModifier())
            .onTapGesture {
                model.selectedOPDSContent = marker
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


    }
}
