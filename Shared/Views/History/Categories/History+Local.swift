//
//  History+LocalContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-22.
//

import Kingfisher
import RealmSwift
import SwiftUI

extension HistoryView {
    struct LocalContentTile: View {
        var marker: HistoryObject
        var size = 140.0
        @EnvironmentObject var model: HistoryView.ViewModel
        var body: some View {
            if let id = Int64(marker.contentId), let book = LocalContentManager.shared.getBook(withId: id) {
                ContentFound(book)
                    .onTapGesture {
                        model.selectedBook = book
                    }
                    .modifier(StyleModifier())

            }
        }

        // Views
        @ViewBuilder
        func ContentFound(_ book: LocalContentManager.Book) -> some View {
            HStack {
                GeometryReader { proxy in
                    KFImage.source(book.getImageSource())
                        .diskCacheExpiration(.expired)
                        .downsampling(size: proxy.size)
                        .fade(duration: 0.30)
                        .resizable()
                }
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .background(Color.fadedPrimary)
                .cornerRadius(7)

                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    Text("On My \(UIDevice.current.model)")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)

                    Text(marker.dateRead!.timeAgo())
                        .font(.footnote)
                        .fontWeight(.light)
                        .foregroundColor(.gray)
                }

                Spacer()

                HistoryView.ProgressIndicator(progress: marker.progress)
            }
        }
    }
}
