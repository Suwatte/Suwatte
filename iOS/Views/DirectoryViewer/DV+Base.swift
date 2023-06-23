//
//  DV+Base.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//

import Foundation
import SwiftUI



extension DirectoryViewer {
    struct Coreview: View {
        @StateObject var model = DirectoryViewer.CoreModel()
        var body: some View {
            DirectoryViewer(model: .init())
                .fullScreenCover(isPresented: $model.displayReader) {
                    let chapters = model.preppedChapters!
                    let target = chapters.first!
                    ReaderGateWay(readingMode: .PAGED_COMIC, chapterList: chapters, openTo: target)
                }
                .environmentObject(model)
        }
    }
}
