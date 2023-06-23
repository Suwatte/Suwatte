//
//  STT+Bundle.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-28.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    var releaseVersionNumberPretty: String {
        return "\(releaseVersionNumber ?? "1.0.0") Build \(buildVersionNumber ?? "0.0.1")"
    }
}
