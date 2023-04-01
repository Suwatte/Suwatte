//
//  STT+URL.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension URL {
    func createDirectory() {
        try? FileManager.default.createDirectory(at: self, withIntermediateDirectories: true, attributes: nil)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var contents: [URL] {
        let out = try? FileManager.default.contentsOfDirectory(at: self,
                                                               includingPropertiesForKeys: [.contentModificationDateKey],
                                                               options: .skipsHiddenFiles)
        return out ?? []
    }

    var lastModified: Date {
        let date = try? resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return date ?? .distantPast
    }

    var sttBase: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.path = ""
        return components?.url
    }
}

extension URL {
    func absoluteStringByTrimmingQuery() -> String? {
        if var urlcomponents = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            urlcomponents.query = nil
            return urlcomponents.string
        }
        return nil
    }
}
