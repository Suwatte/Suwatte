//
//  JSCCT+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import Foundation

struct TrackerInfo: RunnerInfo {
    var id: String
    var name: String
    var version: Double
    var minSupportedAppVersion: String?
    var thumbnail: String?
    
    var website: String
}
