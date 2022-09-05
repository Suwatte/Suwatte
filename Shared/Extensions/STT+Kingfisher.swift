//
//  STT+Kingfisher.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-05.
//

import Foundation
import Kingfisher
import UIKit

struct WhiteSpaceProcessor: ImageProcessor {
    // `identifier` should be the same for processors with the same properties/functionality
    // It will be used when storing and retrieving the image to/from cache.
    let identifier = "com.suwatte.wsp"

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            return image.withWhitespaceCropped()
        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }
}

struct STTCallbackProcessor: ImageProcessor {
    let identifier: String = "com.suwatte.cbp"
    let action: (KFCrossPlatformImage) -> Void
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(kFCrossPlatformImage):
            action(kFCrossPlatformImage)
            return kFCrossPlatformImage

        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }
}

struct STTDownsamplerProcessor: ImageProcessor {
    let identifier = "com.suwatte.dsp"

    // Convert input data/image to target image and return it.
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> KFCrossPlatformImage? {
        switch item {
        case let .image(image):
            let newSize = image.size.scaledTo(UIScreen.main.bounds.size)

            guard let data = image.kf.data(format: .unknown) else {
                return nil
            }
            return KingfisherWrapper.downsampledImage(data: data, to: newSize, scale: options.scaleFactor)
        case .data:
            return (DefaultImageProcessor.default |> self).process(item: item, options: options)
        }
    }
}
