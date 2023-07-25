//
//  SDM+Fetcher.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation


extension SDM {
    internal func getImages(id: String) async throws -> (urls: [URL], raws: [Data], text: String?) {
        let identifier = parseID(id)
        
        let source = try DSK.shared.getContentSource(id: identifier.source)

        let data = try await source.getChapterData(contentId: identifier.content, chapterId: identifier.chapter)

        let urls = data.pages?.compactMap { URL(string: $0.url ?? "") } ?? []
        let raws = data.pages?.compactMap { $0.raw }.compactMap { Data(base64Encoded: $0) } ?? []
        let text = data.text
        return (urls: urls, raws: raws, text: text)
    }
}
