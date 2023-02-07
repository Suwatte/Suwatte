//
//  HistoryView+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-20.
//

import Foundation
import Combine
import RealmSwift
import OrderedCollections

extension HistoryView {
    
    final class ViewModel: ObservableObject {
        
        var token: NotificationToken?
        @Published var markers: OrderedSet<HistoryObject>  = []
        @Published var selection: HighlightIndentier?
        @Published var selectedBook: LocalContentManager.Book?
        @Published var selectedOPDSContent: HistoryObject?
        init() {
            observe()
        }
        
        func observe() {
            
            let realm = try! Realm()
            
            let threeMonths = Calendar.current.date(
                byAdding: .month,
                value: -3,
                to: .now
            )!
            let results  = realm
                .objects(ChapterMarker.self)
                .where({ $0.chapter != nil })
                .where({ $0.dateRead != nil })
                .where({ $0.dateRead >= threeMonths })
                .sorted(by: \.dateRead, ascending: false)
                .distinct(by: ["chapter.sourceId", "chapter.contentId"])
            
            token = results
                .observe { [weak self] _ in
                    self?.markers = OrderedSet(results.map({ $0.chapter?.sourceId != STTHelpers.OPDS_CONTENT_ID ? $0.toHistoryObject() : $0.toOPDSHistoryObject() }))
                }

        }
        
        func removeObserver() {
            token?.invalidate()
            token = nil
        }
    }
    
}
