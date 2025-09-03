//
//  UpdateFeedTile.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import RealmSwift
import SwiftUI

extension UpdateFeedView {
    struct UpdateFeedTile: View {
        var entry: LibraryEntry
        var body: some View {
            HStack {
                ImageView

                VStack(alignment: .leading, spacing: 5) {
                    Text(readable.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("^[\(entry.updateCount) Update](inflect: true)")
                        .font(.callout)
                        .foregroundColor(.gray)
                    if entry.linkedHasUpdates {
                        Text("Updates Available on Linked Content")
                            .font(.callout)
                            .foregroundColor(.green)
                    }
                    Spacer()
                    Text("Last Updated: \(entry.lastUpdated.timeAgo())")
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .frame(height: 75 * 1.5)
            .contentShape(Rectangle())
        }

        var ImageView: some View {
            STTImageView(url: URL(string: readable.cover), identifier: readable.ContentIdentifier)
                .frame(width: 75, height: 75 * 1.5, alignment: .center)
                .scaledToFit()
                .cornerRadius(5)
                .padding(.vertical, 3)
        }

        var readable: StoredContent {
            entry.content!
        }
    }
}
