//
//  ProfileView+RelatedContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-09.
//

import ASCollectionView
import RealmSwift
import SwiftUI

extension ProfileView.Skeleton {
    struct RelatedContentView: View {
        typealias Highlight = DaisukeEngine.Structs.Highlight
        var collections: [DaisukeEngine.Structs.HighlightCollection]
        @EnvironmentObject var source: DaisukeContentSource
        @EnvironmentObject var model: ProfileView.ViewModel

        var body: some View {
            VStack(alignment: .leading) {
                ForEach(collections.filter { !$0.highlights.isEmpty }) {
                    CollectionView(collection: $0)
                }
            }
        }
    }
}

extension ProfileView.Skeleton.RelatedContentView {
    struct CollectionView: View {
        var collection: DSKCommon.HighlightCollection

        var body: some View {
            VStack(alignment: .leading) {
                Text(collection.title)
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(collection.highlights) {
                            Cell(data: $0)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    struct Cell: View {
        @EnvironmentObject var source: DaisukeContentSource
        @EnvironmentObject var model: ProfileView.ViewModel
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.SEPARATED
        var data: Highlight

        var body: some View {
            NavigationLink {
                ProfileView(entry: data, sourceId: source.id)
            } label: {
                DefaultTile(entry: data, sourceId: source.id)
                    .frame(width: 150, height: CELL_HEIGHT)
            }
            .buttonStyle(NeutralButtonStyle())
        }

        var CELL_HEIGHT: CGFloat {
            let base: CGFloat = 150
            var height = 1.5 * base

            if style == .SEPARATED {
                height += 50
            }
            return height
        }
    }
}
