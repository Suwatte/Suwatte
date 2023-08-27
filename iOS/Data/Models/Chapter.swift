//
//  Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class StoredChapter: Object, Identifiable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var sourceId: String
    @Persisted var contentId: String
    @Persisted var chapterId: String

    @Persisted var index: Int
    @Persisted var number: Double
    @Persisted var volume: Double?
    @Persisted var title: String?
    @Persisted var language: String?
    @Persisted var date: Date
    @Persisted var webUrl: String?
    @Persisted var thumbnail: String?
    @Persisted var providers: List<ChapterProvider>

    var displayName: String {
        var str = ""
        if let volume = volume, volume != 0 {
            str += "Volume \(volume.clean)"
        }
        str += " Chapter \(number.clean)"
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var chapterName: String {
        "Chapter \(number.clean)"
    }

    var contentIdentifier: ContentIdentifier {
        .init(contentId: contentId, sourceId: sourceId)
    }
    
    var chapterOrderKey: Double {
        ThreadSafeChapter.orderKey(volume: volume, number: number)
    }
}
