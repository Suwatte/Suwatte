//
//  ComicInfo.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-23.
//  Swift Implementation of the ComicInfo XML Schema by the anansi-project
//  Reference: https://github.com/anansi-project/comicinfo/blob/main/schema/v1.0/ComicInfo.xsd

import Foundation
import Fuzi

enum YesNo: String {
    case unknown = "Unknown"
    case no = "No"
    case yes = "Yes"
}

struct ComicInfo {
    var title: String?
    var series: String?
    var number: String?
    var count: Int?
    var volume: Int?
    var alternateSeries: String?
    var alternateNumber: String?
    var alternateCount: Int?
    var summary: String?
    var notes: String?
    var year: Int?
    var month: Int?
    var writer: String?
    var penciller: String?
    var inker: String?
    var colorist: String?
    var letterer: String?
    var coverArtist: String?
    var editor: String?
    var publisher: String?
    var imprint: String?
    var genre: String?
    var web: String?
    var pageCount: Int?
    var languageISO: String?
    var format: String?
    var blackAndWhite: YesNo?
    var manga: YesNo?
}
