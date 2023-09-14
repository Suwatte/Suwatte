//
//  Realm+Statistics.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-13.
//

import Foundation
import RealmSwift

extension Sequence where Element: Hashable {
    var histogram: [Element: Int] {
        return self.reduce(into: [:]) { counts, elem in counts[elem, default: 0] += 1 }
    }
}

struct LibraryStatistics : Hashable {
    let total: Int
    let runners: [StoredRunnerObject: Int]
    let status: [ContentStatus: Int]
    let flag: [LibraryFlag: Int]
    let type: [ExternalContentType: Int]
    let chaptersRead: Int
    let bookmarks: Int
    let collections: Int
    let downloads: Int
    let savedForLater: Int
    let nsfw: Int

    
    let customThumbnails: Int
    
    let newThisMonth: Int
    let openedTitles: Int
    
    let pagesRead: Int
    let pixelsScrolled: Double
    
    let tags: [String: Int]
}


extension RealmActor {
    
    func getLibraryStatistics() -> LibraryStatistics {
        
        // Get Total Library Count
        let totalLibraryCount = realm
            .objects(LibraryEntry.self)
            .where { $0.content != nil && !$0.isDeleted }
            .count
        
        let chaptersRead = realm
            .objects(ProgressMarker.self)
            .where { !$0.isDeleted }
            .map(\.readChapters.count)
            .reduce(0, +)
        
        let bookmarks = realm
            .objects(UpdatedBookmark.self)
            .where { !$0.isDeleted }
            .count
        
        let collections = realm
            .objects(LibraryCollection.self)
            .where { !$0.isDeleted }
            .count
        
        let downloads = realm
            .objects(SourceDownloadIndex.self)
            .map(\.count)
            .reduce(0, +)
        
        let savedForLater = realm
            .objects(ReadLater.self)
            .where { !$0.isDeleted }
            .count
        
        
        var runnerMap: [StoredRunnerObject:Int] = [:]
        
        let runners = getSavedAndEnabledSources().freeze().toArray()
        
        for source in runners {
            let sourceID = source.id
            let count = realm
                .objects(LibraryEntry.self)
                .where { !$0.isDeleted && $0.content.sourceId == sourceID }
                .count
            
            runnerMap[source] = count
        }
        
        let nsfw = realm
            .objects(LibraryEntry.self)
            .where { !$0.isDeleted && $0.content.isNSFW == true }
            .count
        
        let customThumbs = realm
            .objects(CustomThumbnail.self)
            .where { !$0.isDeleted }
            .count
        
        let opened = realm
            .objects(StoredContent.self)
            .count
        
        let thisMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now))!
        let newThisMonth = realm
            .objects(LibraryEntry.self)
            .where { !$0.isDeleted && $0.dateAdded <= thisMonth }
            .count
        
        let statuses = ContentStatus.allCases.removing(.UNKNOWN)
        
        var statusMap: [ContentStatus: Int] = [:]
        
        for status in statuses {
            let count = realm
                .objects(LibraryEntry.self)
                .where { !$0.isDeleted && $0.content.status == status }
                .count
            
            statusMap[status] = count
        }
        
        var flagMap: [LibraryFlag: Int] = [:]
        let flags = LibraryFlag.allCases
        for flag in flags {
            let count = realm
                .objects(LibraryEntry.self)
                .where { !$0.isDeleted && $0.flag == flag }
                .count
            
            flagMap[flag] = count
        }
        
        var typeMap : [ExternalContentType: Int] = [:]
        for eType in ExternalContentType.allCases {
            let count = realm
                .objects(LibraryEntry.self)
                .where { !$0.isDeleted && $0.content.contentType == eType }
                .count
            
            typeMap[eType] = count
        }
        
        let readingStats = realm.object(ofType: UserReadingStatistic.self, forPrimaryKey: "default")
        
        let tags = realm
            .objects(LibraryEntry.self)
            .where { !$0.isDeleted && $0.content != nil }
            .freeze()
            .toArray()
            .flatMap(\.content!.properties)
            .flatMap(\.tags)
            .map { $0.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .histogram
            .filter({ $0.value >= 3 })
        
        return .init(total: totalLibraryCount,
                     runners: runnerMap,
                     status: statusMap,
                     flag: flagMap,
                     type: typeMap,
                     chaptersRead: chaptersRead,
                     bookmarks: bookmarks,
                     collections: collections,
                     downloads: downloads,
                     savedForLater: savedForLater,
                     nsfw: nsfw,
                     customThumbnails: customThumbs,
                     newThisMonth: newThisMonth,
                     openedTitles: opened,
                     pagesRead: readingStats?.pagesRead ?? 0,
                     pixelsScrolled: readingStats?.pixelsScrolled ?? 0,
                     tags: tags)
        
    }
}



extension RealmActor {
    func getStatsObject() async -> UserReadingStatistic {
        let target = realm
            .object(ofType: UserReadingStatistic.self, forPrimaryKey: "default")
        
        guard let target else {
            let newObject = UserReadingStatistic()
            await operation {
                realm.add(newObject, update: .all)
            }
            return newObject
        }
        
        return target
    }
    func addPageToStatistics() async {
        let stats = await getStatsObject()
        
        await operation {
            stats.pagesRead += 1
        }
        
    }
    func addOffsetToStatistics(_ value: CGFloat) async {
        let stats = await getStatsObject()
        
        await operation {
            stats.pixelsScrolled += Double(value)
        }
    }
}
