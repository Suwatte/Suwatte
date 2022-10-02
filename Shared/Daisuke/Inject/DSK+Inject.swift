//
//  DSK+Inject.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Foundation
import JavaScriptCore

// http://rbereski.info/2015/05/15/java-script-core/
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

extension DaisukeEngine {
    private func add(class cls: AnyClass, name: String, context: JSContext) {
        let constructorName = "__constructor__\(name)"

        let constructor: @convention(block) () -> NSObject = {
            let cls = cls as! NSObject.Type
            return cls.init()
        }

        context.setObject(unsafeBitCast(constructor, to: AnyObject.self),
                          forKeyedSubscript: constructorName as NSCopying & NSObjectProtocol)

        let script = "function \(name)() " +
            "{ " +
            "   var obj = \(constructorName)(); " +
            "   obj.setThisValue(obj); " +
            "   return obj; " +
            "} "

        context.evaluateScript(script)
    }
}

extension DaisukeEngine {
    func injectLogger(_ context: JSContext) {
        context.evaluateScript("var console = { log: function(message, ...options) { daisuke_log(JSON.stringify(message), options.map(JSON.stringify)) } }")
        let consoleLog: @convention(block) (JSValue, JSValue) -> Void = {
            DSK.shared.consoleLog(message: $0, options: $1)
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self),
                          forKeyedSubscript: "daisuke_log" as NSCopying & NSObjectProtocol)
    }

    func injectCommonLibraries(_ context: JSContext) {
        

        do {
            let content = try String(contentsOf: commons, encoding: .utf8)
            _ = context.evaluateScript(content)
        } catch {
            Logger.shared.error(error.localizedDescription, .init(file: #file, function: #function, line: #line))
        }
    }

    func injectDataClases(_ context: JSContext) {
        add(class: ValueStore.self, name: "ValueStore", context: context)
        add(class: KeyChainStore.self, name: "KeyChainStore", context: context)
        add(class: NetworkClient.self, name: "NetworkClient", context: context)
//        add(class: Console.self, name: "Console", context: context)
    }
}
