//
//  STT+Nuke.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-24.
//

import Nuke
import UIKit

struct NukeWhitespaceProcessor: ImageProcessing, Hashable {
    func process(_ image: Nuke.PlatformImage) -> Nuke.PlatformImage? {
        let rect = try? image.croppedWhitespaceRect()
        guard let rect, let cropped = image.cgImage?.cropping(to: rect) else {
            return image
        }
        
        
        return PlatformImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    var identifier: String {
        Bundle.main.bundleIdentifier! + ".image_processor.whitespace"
    }
    
    var hashableIdentifier: AnyHashable {
        self
    }
    
}

struct NukeDownsampleProcessor: ImageProcessing, Hashable {
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

        guard let data, let out = ds(data, size, image.scale) else {
            return nil
        }
        
        return .init(cgImage: out, scale: image.scale, orientation: image.imageOrientation)
    }

    var identifier: String {
        Bundle.main.bundleIdentifier! + ".image_processor.downsample?w=\(width),h=\(height)"
    }

    var hashableIdentifier: AnyHashable {
        self
    }
    
    func ds(_ data: Data, _ size: CGSize, _ scale: CGFloat) -> CGImage? {
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


struct NukeSplitWidePageProcessor: ImageProcessing, Hashable {
    private let half: UIImage.ImageHalf
    private let page: PanelPage
    init(half: UIImage.ImageHalf, page: PanelPage) {
        self.half = half
        self.page = page
    }
    
    func process(_ image: Nuke.PlatformImage) -> Nuke.PlatformImage? {
        let isWide = image.size.ratio > 1
        
        if isWide && !page.isSplitPageChild { // fire if the page is wide AND is the primary page
            PanelPublisher.shared.willSplitPage.send(page)
        }
        return isWide ? image.split(take: half) : image
    }
    
    var identifier: String {
        Bundle.main.bundleIdentifier! + ".image_processor.split_wide?h=\(half)"
    }
    
    var hashableIdentifier: AnyHashable {
        self
    }
}
