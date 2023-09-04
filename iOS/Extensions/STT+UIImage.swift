//
//  STT+UIImage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-05.
//

import CoreGraphics
import UIKit

// Average Color of Image
extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

extension CGSize {
    func scaledTo(_ target: CGSize) -> CGSize {
        let ratio = width / height
        let scaledHeight = target.width / ratio

        return CGSize(width: target.width, height: scaledHeight)
    }
}

// MARK: Splitting

// Reference: https://stackoverflow.com/a/33091111
extension UIImage {
    func leftHalf() -> UIImage {
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale

        let rect = CGRect(origin: .zero, size: .init(width: scaledWidth / 2, height: scaledHeight))
        return cgImage?.cropping(to: rect)?.image ?? self
    }

    func rightHalf() -> UIImage {
        let scaledWidth = size.width * scale
        let scaledHeight = size.height * scale
        let origin = CGPoint(x: scaledWidth - (scaledWidth / 2), y: .zero)

        let rect = CGRect(origin: origin, size: .init(width: scaledWidth - (scaledWidth / 2), height: scaledHeight))
        return cgImage?.cropping(to: rect)?.image ?? self
    }
}

extension CGImage {
    var image: UIImage { .init(cgImage: self) }
}

extension CGSize {
    var ratio: CGFloat {
        width / height
    }

    var isLandscape: Bool {
        width > height
    }
}

enum ImageScaleOption: Int, CaseIterable, UserDefaultsSerializable {
    case screen, height, width, stretch

    var description: String {
        switch self {
        case .screen:
            return "Fit Screen"
        case .height:
            return "Fit Height"
        case .width:
            return "Fit Width"
        case .stretch:
            return "Stretch"
        }
    }
}

extension UIImage {
    enum ImageHalf {
        case left, right
    }
}

extension UIImage {}
