//
//  SDV+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation
import SwiftUI
import ASCollectionView


extension SourceDownloadView {
    
    struct CollectionView: View {
        @EnvironmentObject var model: ViewModel
        @AppStorage(STTKeys.TileStyle) var style = TileStyle.COMPACT
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        
        var body: some View {
            ASCollectionView(section: AS_SECTION)
                .layout {
                    DynamicGridLayout()
                }
                .alwaysBounceVertical()
                .shouldInvalidateLayoutOnStateChange(true)
                .animateOnDataRefresh(true)
                .ignoresSafeArea(.keyboard, edges: .all)
                // Triggers View Rebuild which trigger collectionview layout invalidaiton
                .onChange(of: PortraitPerRow, perform: { _ in })
                .onChange(of: LSPerRow, perform: { _ in })
                .onChange(of: style, perform: { _ in })
        }
    }
    
    
}


extension SourceDownloadView.CollectionView {
    var AS_SECTION: ASSection<Int> {
        return ASSection(id: 0, data: model.entries) { data, _ in
            Cell(for: data)
        }
        .sectionHeader(content: {
            EmptyView()
        })
        .sectionFooter(content: {
            EmptyView()
        })
    }
}

extension SourceDownloadView.CollectionView {
    @ViewBuilder
    func Cell(for idx: SourceDownloadIndex) -> some View {
        let sourceId = idx.content?.sourceId ?? ""
        let highlight = getHighlight(idx)
        
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                ProfileView(entry: highlight, sourceId: sourceId)
            } label: {
                DefaultTile(entry: highlight, sourceId: sourceId)
            }
            .buttonStyle(NeutralButtonStyle())
        }
    }
    
    
    func getHighlight(_ idx: SourceDownloadIndex) -> DSKCommon.Highlight {
        let entry = idx.content ?? StoredContent()
        
        var highlight = entry.toHighlight()
        highlight.subtitle = "\(idx.count) Chapter(s)"
        return highlight
    }
}
