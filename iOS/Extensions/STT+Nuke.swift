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
        guard let cgImage = image.cgImage else {
            return image
        }
        let rect = try? croppedWhitespaceRect(cgImage)

        guard let rect else {
            return image
        }

        // Reference: https://www.advancedswift.com/crop-image/
        // Not the most efficient solution but this prevents a very annoying memeory leak when uisng CGImage.cropping(to:) on a background thread.
        let out = UIGraphicsImageRenderer(
            size: rect.size,
            format: image.imageRendererFormat
        ).image { _ in
            // If rect.origin != (0,0) image is slightly offset in canvas, fix by moving the drawing position to start at the origin of the canvas
            image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }

        return out
    }

    var identifier: String {
        Bundle.main.bundleIdentifier! + ".image_processor.whitespace"
    }

    var hashableIdentifier: AnyHashable {
        self
    }

    // Reference : https://stackoverflow.com/a/40780523
    func croppedWhitespaceRect(_ cgImage: CGImage) throws -> CGRect? {
        var out: CGRect? = nil
        let cgWidth = cgImage.width
        let cgHeight = cgImage.height
        let bitmapBytesPerRow = cgWidth * 4
        let bitmapByteCount = bitmapBytesPerRow * cgHeight

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: bitmapByteCount)

        let context = CGContext(data: pointer,
                                width: cgWidth,
                                height: cgHeight,
                                bitsPerComponent: 8,
                                bytesPerRow: bitmapBytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        defer {
            pointer.deallocate()
        }

        guard let context else {
            return nil
        }

        let height = CGFloat(cgImage.height)
        let width = CGFloat(cgImage.width)

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(rect)
        context.draw(cgImage, in: rect)

        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        var lowX = width
        var lowY = height
        var highX: CGFloat = 0
        var highY: CGFloat = 0

        let heightInt = Int(height)
        let widthInt = Int(width)
        let whiteThreshold = 0xE0
        for y in 0 ..< heightInt {
            let y = CGFloat(y)
            try Task.checkCancellation()
            for x in 0 ..< widthInt {
                let x = CGFloat(x)
                let pixelIndex = (width * y + x) * 4 /* 4 for A, R, G, B */
                let idx = Int(pixelIndex)
                let alpha = data[idx]
                guard alpha != 0 else { continue } // Transparent
                let red = data[idx + 1]
                let green = data[idx + 2]
                let blue = data[idx + 3]
                if red > whiteThreshold, green > whiteThreshold, blue > whiteThreshold { continue } // White
                lowX = min(lowX, x)
                highX = max(highX, x)
                lowY = min(lowY, y)
                highY = max(highY, y)
            }
        }

        out = CGRect(x: lowX, y: lowY, width: highX - lowX, height: highY - lowY)
        context.clear(rect)
        return out
    }
}

struct NukeDownsampleProcessor: ImageProcessing, Hashable {
    private let width: CGFloat
    private let height: CGFloat
    private let scale: CGFloat
    init(width: CGFloat, scale: CGFloat) {
        self.width = width
        height = .infinity
        self.scale = scale
    }

    init(size: CGSize, scale: CGFloat) {
        width = size.width
        height = size.height
        self.scale = scale
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

    func ds(_ data: Data, _ size: CGSize, _: CGFloat) -> CGImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }

        let maxDimensionInPixels = max(size.width, size.height) * scale
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
        return isWide ? split(take: half, image: image) : image
    }

    var identifier: String {
        Bundle.main.bundleIdentifier! + ".image_processor.split_wide?h=\(half)"
    }

    var hashableIdentifier: AnyHashable {
        self
    }

    func split(take half: UIImage.ImageHalf, image: UIImage) -> UIImage? {
        let size = image.size
        func getRect() -> CGRect {
            switch half {
            case .left:
                return CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
            case .right:
                return CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height)
            }
        }

        let rect = getRect()

        let out = UIGraphicsImageRenderer(
            size: rect.size,
            format: image.imageRendererFormat
        ).image { _ in
            // If rect.origin != (0,0) image is slightly offset in canvas, fix by moving the drawing position to start at the origin of the canvas
            image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        }

        return out
    }
}
