//
//  History+ContentSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import SwiftUI

extension HistoryView {
    struct ContentSourceCell: View {
        var marker: ProgressMarker
        var content: StoredContent
        var chapter: ChapterReference
        var size = 140.0

        var body: some View {
            HStack {
                STTImageView(url: URL(string: content.cover), identifier: content.ContentIdentifier)
                    .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                    .scaledToFit()
                    .cornerRadius(5)
                    .shadow(radius: 3)

                VStack(alignment: .leading, spacing: 3.5) {
                    Text(content.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    VStack(alignment: .leading) {
                        Text(chapter.chapterName)
                        if let dateRead = marker.dateRead {
                            Text(dateRead.timeAgo())
                        }
                    }
                    .font(.footnote.weight(.light))
                    .foregroundColor(.gray)
                    Spacer()
                }
                .frame(minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .padding(.top, 1.5)
                Spacer()
                HistoryView.ProgressIndicator(progress: marker.isCompleted ? 1.0 : marker.progress ?? 0.0)
            }
        }
    }
}
