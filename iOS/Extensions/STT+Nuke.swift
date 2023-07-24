//
//  STT+Nuke.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-24.
//

import Nuke
import UIKit

struct NukeWhitespaceProcessor: ImageProcessing {
    func process(_ image: Nuke.PlatformImage) -> Nuke.PlatformImage? {
        return image.withWhitespaceCropped()
    }

    var identifier: String = Bundle.main.bundleIdentifier! + ".image_processor.whitespace"
}

struct NukeDownsampleProcessor: ImageProcessing {
    private let width: CGFloat
    private let height: CGFloat
    init(width: CGFloat) {
        self.width = width
        height = .infinity
    }

    init(size: CGSize) {
        width = size.width
        height = size.height
    }

    func process(_ image: Nuke.PlatformImage) -> Nuke.PlatformImage? {
        let ratio = min(width / image.size.width, height / image.size.height)

        guard ratio < 1 else {
            return image
        }

        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let data = image.pngData()

        guard let data, let out = ds(data, size) else {
            return nil
        }

        return .init(cgImage: out, scale: UIScreen.main.scale, orientation: image.imageOrientation)
    }

    var identifier: String = Bundle.main.bundleIdentifier! + ".image_processor.downsample"

    func ds(_ data: Data, _ size: CGSize) -> CGImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let maxDimensionInPixels = max(size.width, size.height) * UIScreen.main.scale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels,
        ]
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return downsampledImage
    }
}
