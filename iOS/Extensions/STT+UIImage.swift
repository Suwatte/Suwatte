//
//  STT+UIImage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-05.
//

import UIKit
import CoreGraphics

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

// Returns Image with redundant whitespace cropped
extension UIImage {
    // Reference : https://stackoverflow.com/a/40780523
    func withWhitespaceCropped() -> UIImage {
        let newRect = try? croppedWhitespaceRect()
        
        guard let newRect, let ref = cgImage?.cropping(to: newRect) else {
            return self
        }
        
        let image = UIImage(cgImage: ref, scale: scale, orientation: imageOrientation)
                
        return image
    }
    
    func croppedWhitespaceRect() throws -> CGRect? {
        var out: CGRect? = nil
        guard let cgImage  else { return nil }

        let cgData = cgImage.dataProvider?.data
        guard let cgData, let data = CFDataGetBytePtr(cgData) else { return nil }

        try autoreleasepool {
            
            let height = CGFloat(cgImage.height)
            let width = CGFloat(cgImage.width)
            

            // let data = UnsafePointer<CUnsignedChar>(CGBitmapContextGetData(context))
//            guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else {
//                return
//            }
            
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
                        autoreleasepool {
                            let x = CGFloat(x)
                            let pixelIndex = (width * y + x) * 4 /* 4 for A, R, G, B */
                            let idx = Int(pixelIndex)
                            let alpha = data[idx]
    //
                            guard alpha != 0 else { return } // Transparent
    //
    //
                            let red = data[idx + 1]
                            let green = data[idx + 2]
                            let blue = data[idx + 3]
    ////
                            if red > whiteThreshold, green > whiteThreshold, blue > whiteThreshold { return } // crop white
                            lowX = min(lowX, x)
                            highX = max(highX, x)
                            lowY = min(lowY, y)
                            highY = max(highY, y)
                        }
                    }
                }

            // Filter through data and look for non-transparent pixels.
            out = CGRect(x: lowX, y: lowY, width: highX - lowX, height: highY - lowY)
        }
        return out
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
    
    func split(take half: ImageHalf) -> UIImage? {
        
        func getRect() -> CGRect {
            switch half {
            case .left:
                return CGRect(x: 0, y: 0, width: size.width/2, height: size.height)
            case .right:
                return CGRect(x: size.width/2, y: 0, width: size.width/2, height: size.height)
            }
        }
        
        let rect = getRect()
        
        let img = cgImage?.cropping(to: rect)
        
        guard let img else { return nil }
        
        return .init(cgImage: img, scale: scale, orientation: imageOrientation)
    }
}


extension UIImage {
    func sideBySide(with image: UIImage) -> UIImage? {
        
        let width = size.width + image.size.width
        let height = max(size.height, image.size.height)
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: (height - self.size.height) / 2, width: self.size.width, height: self.size.height))
        image.draw(in: CGRect(x: self.size.width, y: (height - image.size.height) / 2, width: image.size.width, height: image.size.height))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
}
