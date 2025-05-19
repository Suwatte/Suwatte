//
//  Panel+PageLoader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-04.
//

import Alamofire
import Foundation
import KeychainSwift
import Nuke
import UIKit

// Global actor that handles image loading
@globalActor actor PanelActor: GlobalActor {
    static let shared = PanelActor()
    public static func run<T>(resultType _: T.Type = T.self, body: @Sendable () async throws -> T) async rethrows -> T where T: Sendable {
        try await body()
    }
}

extension PanelActor {
    struct PageData: Sendable {
        let data: PanelPage
        let size: CGSize
        let fitToWidth: Bool
        let isPad: Bool

        var page: ReaderPage {
            data.page
        }
    }

    func loadPage(for data: PageData) async throws -> ImageTask {
        let request = try await getImageRequest(for: data)
        guard let request else {
            throw DSK.Errors.NamedError(name: "PanelPageLoader", message: "No handler resolved the requested page.")
        }

        let task = ImagePipeline.shared.imageTask(with: request)
        return task
    }
}

extension PanelActor {
    private func prepareProcessors(for data: PageData) async -> [ImageProcessing] {
        let page = data.page
        let size = data.size
        var processors = [ImageProcessing]()
        let cropWhiteSpaces = Preferences.standard.cropWhiteSpaces
        let downSampleImage = Preferences.standard.downsampleImages
        let isVertical = Preferences.standard.currentReadingMode == .VERTICAL

        let readingMode = Preferences.standard.currentReadingMode
        let shouldSplit = [ReadingMode.PAGED_COMIC, .PAGED_MANGA].contains(readingMode) && Preferences.standard.splitWidePages && Preferences.standard.imageScaleType != .height && Preferences.standard.imageScaleType != .stretch

        // Should Redraw Image
        let sourceID = data.data.page.chapter.sourceId
        if let hostedURL = page.hostedURL,
           !STTHelpers.isInternalSource(sourceID),
           let source = await DSK.shared.getSource(id: sourceID),
           source.intents.isRedrawingHandler ?? false,
           (try? await source.shouldRedrawImage(url: hostedURL).state) ?? false
        {
            processors.append(NukeDaisukeRedrawWithSizeProcessor(sourceID: sourceID))
        }

        if shouldSplit, !data.isPad { // Don't split on ipads
            let isSecondaryPage = data.data.isSplitPageChild
            let useRight = (readingMode == .PAGED_COMIC && isSecondaryPage) || (readingMode == .PAGED_MANGA && !isSecondaryPage)
            let half: UIImage.ImageHalf = useRight ? .right : .left

            processors.append(NukeSplitWidePageProcessor(half: half, page: data.data))
        }

        if downSampleImage {
            if data.fitToWidth {
                processors.append(NukeDownsampleProcessor(width: size.width, scale: await UIScreen.main.scale))
            } else {
                processors.append(NukeDownsampleProcessor(size: size, scale: await UIScreen.main.scale))
            }
        } else {
            if data.fitToWidth {
                processors.append(ImageProcessors.Resize(width: size.width, unit: .points))
            } else {
                processors.append(ImageProcessors.Resize(size: size, unit: .points))
            }
        }

        if cropWhiteSpaces && !isVertical {
            processors.append(NukeWhitespaceProcessor())
        }

        return processors
    }
}

extension PanelActor {
    private func getImageRequest(for data: PageData) async throws -> ImageRequest? {
        var request: ImageRequest?
        let page = data.page

        // Hosted Image
        if let hostedURL = page.hostedURL, let url = URL(string: hostedURL) {
            // Load Hosted Image
            request = try await loadImageFromNetwork(url, data)
        }

        // Downloaded
        else if let url = page.downloadURL {
            // Load Downloaded Image
            request = try await loadImageFromDownloadFolder(url, data)
        }

        // Archive
        else if let archivePath = page.archivePath, let file = page.archiveFile {
            request = try await loadImageFromArchive(file, archivePath, page.CELL_KEY, data)
        }

        // Raw Data
        else if let rawData = page.rawData {
            request = try await loadImageFromBase64EncodedString(rawData, page.CELL_KEY, data)
        }
        return request
    }

    private func prepareImageURL(_ url: URL, _ data: PageData) async throws -> URLRequest {
        let base = URLRequest(url: url)
        let page = data.page
        let sourceId = page.chapter.sourceId

        // Handle OPDS Content Authorization Header
        if sourceId == STTHelpers.OPDS_CONTENT_ID {
            guard let opds = page.opds else {
                return base
            }
            let keychain = KeychainSwift()
            keychain.synchronizable = true
            let pw = keychain.get("OPDS_\(opds.clientId)")
            guard let pw else {
                return base
            }
            var headers = HTTPHeaders()
            let merge = "\(opds.userName):\(pw)"
            let value = "Basic \(merge.toBase64())"
            headers.add(.init(name: "Authorization", value: value))
            return try .init(url: url, method: .get, headers: headers)
        }
        // Handle External Sources
        guard let source = await DSK.shared.getSource(id: sourceId), source.intents.imageRequestHandler else {
            return .init(url: url)
        }
        let response = try await source.willRequestImage(imageURL: url)
        let request = try response.toURLRequest()
        return request
    }

    private func loadImageFromNetwork(_ url: URL, _ data: PageData) async throws -> ImageRequest {
        let request = try await prepareImageURL(url, data)
        try Task.checkCancellation()
        return ImageRequest(urlRequest: request, processors: await prepareProcessors(for: data))
    }

    private func loadImageFromDownloadFolder(_ url: URL, _ data: PageData) async throws -> ImageRequest {
        let request = ImageRequest(url: url, processors: await prepareProcessors(for: data), options: .disableDiskCache)
        return request
    }

    private func loadImageFromBase64EncodedString(_ str: String, _ key: String, _ data: PageData) async throws -> ImageRequest {
        var request = ImageRequest(id: key) {
            let data = Data(base64Encoded: str)
            try Task.checkCancellation()
            guard let data else {
                throw DSK.Errors.NamedError(name: "Image Loader", message: "Failed to decode image from base64 string. Please report this to the source authors.")
            }

            return data
        }
        request.options = .disableDiskCache
        request.processors = await prepareProcessors(for: data)

        return request
    }

    private func loadImageFromArchive(_ file: URL, _ path: String, _ key: String, _ data: PageData) async throws -> ImageRequest {
        var request = ImageRequest(id: key) {
            try ArchiveHelper().getImageData(for: file, at: path)
        }

        request.options = .disableDiskCache
        request.processors = await prepareProcessors(for: data)
        return request
    }
}
