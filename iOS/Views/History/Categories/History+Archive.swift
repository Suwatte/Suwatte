//
//  History+Archive.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//
import Foundation
import SwiftUI

extension HistoryView {
    struct ArchiveCell: View {
        var marker: ProgressMarker
        var file: File
        var size = 140.0
        @EnvironmentObject var model: ViewModel
        var body: some View {
            HStack {
                BaseImageView(request: file.imageRequest(.init(width: size, height: size * 1.5)))
                    .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                    .scaledToFit()
                    .cornerRadius(5)
                    .shadow(radius: 3)

                VStack(alignment: .leading, spacing: 3.5) {
                    Text(file.cName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(3)
                    VStack(alignment: .leading) {
                        if let issue = file.metaData?.issue {
                            Text("Issue #\(issue.issue)")
                        }

                        ZStack {
                            if let current = model.currentDownloadFileId, current == file.id {
                                HStack(spacing: 5) {
                                    Text("Downloading")
                                    Image(systemName: "icloud.and.arrow.down")
                                        .shimmering()
                                }
                            } else {
                                Text(file.isOnDevice ? "On My \(UIDevice.current.model) \(Image(systemName: UIDevice.current.model.lowercased()))"
                                    : "iCloud Drive \(Image(systemName: "icloud.and.arrow.down"))")
                            }
                        }

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
