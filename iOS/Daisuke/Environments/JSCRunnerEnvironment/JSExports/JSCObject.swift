//
//  JSCObject.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import JavaScriptCore

@objc protocol JSObjectProtocol: JSExport {
    var setThisValue: (@convention(block) (JSValue) -> Void)? { get }
}

class JSObject: NSObject, JSObjectProtocol {
    var this: JSManagedValue?

    override init() {
        super.init()
    }

    var setThisValue: (@convention(block) (JSValue) -> Void)? {
        return { [unowned self] (value: JSValue) in
            self.this = JSManagedValue(value: value)
        }
    }
}
