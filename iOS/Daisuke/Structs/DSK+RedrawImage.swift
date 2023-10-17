//
//  DSK+RedrawImage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-10-17.
//

import UIKit


extension DSKCommon {
    struct Rect : JSCObject {
        let size: Size
        let origin: Point
    }
    
    struct Size: JSCObject {
        let width: Float
        let height: Float
    }
    
    struct Point: JSCObject {
        let x: Float
        let y: Float
    }
}


extension DSKCommon {
    struct RedrawInstruction: JSCObject {
        let source: DSKCommon.Rect
        let destination: DSKCommon.Rect
    }
    
    struct RedrawCommand: JSCObject {
        let size: DSKCommon.Size
        let commands: [RedrawInstruction]
    }
}


extension DSKCommon.Point {
    var local: CGPoint {
        .init(x:  CGFloat(x), y: CGFloat(y))
    }
}


extension DSKCommon.Size {
    var local: CGSize {
        .init(width: CGFloat(width), height: CGFloat(height))
    }
}

extension DSKCommon.Rect {
    var local: CGRect {
        .init(origin: origin.local, size: size.local)
    }
}
