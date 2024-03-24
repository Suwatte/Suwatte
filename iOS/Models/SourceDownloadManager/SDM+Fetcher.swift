//
//  SDM+Fetcher.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-25.
//

import Foundation

extension SDM {
    func getImages(id: String) async throws -> (urls: [URL], raws: [Data], text: String?) {
        let identifier = parseID(id)

        let source = try await DSK.shared.getContentSource(id: identifier.source)

        let chapter = await get(id)?.chapter?.toThreadSafe()
        guard let chapter else {
            throw DSK.Errors.NamedError(name: "SourceDownloadManager", message: "Unable to get chapter")
        }
        let data = try await source.getChapterData(contentId: identifier.content, chapterId: identifier.chapter, chapter: chapter)

        let urls = data.pages?.compactMap { URL(string: $0.url ?? "") } ?? []
        let raws = data.pages?.compactMap { $0.raw }.compactMap { Data(base64Encoded: $0) } ?? []
        let text = data.text
        return (urls: urls, raws: raws, text: text)
    }
}
