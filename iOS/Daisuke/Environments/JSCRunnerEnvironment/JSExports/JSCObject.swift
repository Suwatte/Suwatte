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

    func getRunnerID() throws -> String {
        guard let runner = this?.value.context.daisukeRunner() else {
            throw DaisukeEngine.Errors.RunnerNotFoundOnContainedObject
        }

        guard let id = runner.forProperty("info")?.forProperty("id")?.toString() else {
            throw DaisukeEngine.Errors.UnableToFetchRunnerIDInContainedObject
        }

        return id
    }
}
