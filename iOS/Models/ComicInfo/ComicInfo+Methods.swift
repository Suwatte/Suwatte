//
//  ComicInfo+Methods.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-23.
//

import Foundation
import Fuzi

extension ComicInfo {
    
    static func fromXML(_ document: XMLDocument) -> ComicInfo? {
        guard let root = document.root else { return nil }
        var comicInfo = ComicInfo()
        comicInfo.title = root.firstChild(tag: "Title")?.stringValue
        comicInfo.series = root.firstChild(tag: "Series")?.stringValue
        comicInfo.number = root.firstChild(tag: "Number")?.stringValue
        comicInfo.count = Int(root.firstChild(tag: "Count")?.stringValue ?? "-1")
        comicInfo.volume = Int(root.firstChild(tag: "Volume")?.stringValue ?? "-1")
        comicInfo.alternateSeries = root.firstChild(tag: "AlternateSeries")?.stringValue
        comicInfo.alternateNumber = root.firstChild(tag: "AlternateNumber")?.stringValue
        comicInfo.alternateCount = Int(root.firstChild(tag: "AlternateCount")?.stringValue ?? "-1")
        comicInfo.summary = root.firstChild(tag: "Summary")?.stringValue
        comicInfo.notes = root.firstChild(tag: "Notes")?.stringValue
        comicInfo.year = Int(root.firstChild(tag: "Year")?.stringValue ?? "-1")
        comicInfo.month = Int(root.firstChild(tag: "Month")?.stringValue ?? "-1")
        comicInfo.writer = root.firstChild(tag: "Writer")?.stringValue
        comicInfo.penciller = root.firstChild(tag: "Penciller")?.stringValue
        comicInfo.inker = root.firstChild(tag: "Inker")?.stringValue
        comicInfo.colorist = root.firstChild(tag: "Colorist")?.stringValue
        comicInfo.letterer = root.firstChild(tag: "Letterer")?.stringValue
        comicInfo.coverArtist = root.firstChild(tag: "CoverArtist")?.stringValue
        comicInfo.editor = root.firstChild(tag: "Editor")?.stringValue
        comicInfo.publisher = root.firstChild(tag: "Publisher")?.stringValue
        comicInfo.imprint = root.firstChild(tag: "Imprint")?.stringValue
        comicInfo.genre = root.firstChild(tag: "Genre")?.stringValue
        comicInfo.web = root.firstChild(tag: "Web")?.stringValue
        comicInfo.pageCount = Int(root.firstChild(tag: "PageCount")?.stringValue ?? "0")
        comicInfo.languageISO = root.firstChild(tag: "LanguageISO")?.stringValue
        comicInfo.format = root.firstChild(tag: "Format")?.stringValue
        comicInfo.blackAndWhite = YesNo(rawValue: root.firstChild(tag: "BlackAndWhite")?.stringValue ?? "Unknown")
        comicInfo.manga = YesNo(rawValue: root.firstChild(tag: "Manga")?.stringValue ?? "Unknown")
        return comicInfo
    }
}
