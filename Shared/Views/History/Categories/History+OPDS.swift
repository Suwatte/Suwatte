//
//  History+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import SwiftUI


extension HistoryView {
    
    struct OPDSCell: View {
        var marker: ProgressMarker
        var content: StreamableOPDSContent
        var chapter: ChapterReference
        var size = 140.0
        
        var body: some View {
            HStack {
                STTImageView(url: URL(string: content.contentThumbnail), identifier: .init(contentId: content.id, sourceId: STTHelpers.OPDS_CONTENT_ID))
                    .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                    .scaledToFit()
                    .cornerRadius(5)
                    .shadow(radius: 3)
                
                VStack(alignment: .leading, spacing: 7) {
                    Text(content.contentTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    VStack(alignment: .leading) {
                        Text("OPDS \(Image(systemName: "dot.radiowaves.up.forward"))")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        if let dateRead = marker.dateRead {
                            Text(dateRead.timeAgo())
                                .font(.footnote)
                                .fontWeight(.light)
                                .foregroundColor(.gray)
                        }
                    }
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
