//
//  ReadLater+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-26.
//

import ASCollectionView
import SwiftUI

// MARK: Collection

extension LibraryView.ReadLaterView {
    struct CollectionView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            ASCollectionView {
                CollectionViewSection
                    .sectionHeader {
                        EmptyView()
                    }
                    .sectionFooter {
                        EmptyView()
                    }
            }
            .layout {
                DynamicGridLayout()
            }
            .alwaysBounceVertical()
            .animateOnDataRefresh(true)
            .ignoresSafeArea(.keyboard, edges: .all)
        }

        var CollectionViewSection: ASSection<Int> {
            .init(id: 0,
                  data: model.readLater,
                  contextMenuProvider: contextMenuProvider)
            { entry, _ in
                Cell(data: entry)
            }
        }
    }
}

// MARK: Cell

extension LibraryView.ReadLaterView {
    struct Cell: View {
        @EnvironmentObject var model: ViewModel
        let data: ReadLater

        // Computed
        var highlight: Highlight { data.content!.toHighlight() }
        var sourceId: String { data.content!.sourceId }
        var inLibrary: Bool { model.library.contains(data.id) }

        // Body
        var body: some View {
            DefaultTile(entry: highlight, sourceId: sourceId)
                .coloredBadge(inLibrary ? .accentColor : nil)
                .onTapGesture {
                    model.selection = (sourceId, highlight)
                }
        }
    }
}
