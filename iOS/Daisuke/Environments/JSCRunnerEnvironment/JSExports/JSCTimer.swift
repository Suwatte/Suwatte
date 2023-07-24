//
//  JSCTimer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-24.
//

import Foundation
import JavaScriptCore

@objc protocol JSCTimerProtocol: JSExport {
    func setTimeout(_ callback: JSValue, _ ms: Double) -> String
    func clearTimeout(_ identifier: String)
    func setInterval(_ callback: JSValue, _ ms: Double) -> String
    func clearInterval(_ identifier: String)
}

@objc class JSCTimer: NSObject, JSCTimerProtocol {
    private var timers = [String: Timer]()
    private var counter: UInt = 0

    func setTimeout(_ callback: JSValue, _ ms: Double) -> String {
        return createTimer(callback: callback, ms: ms, repeats: false)
    }

    func clearTimeout(_ identifier: String) {
        invalidateTimer(identifier: identifier)
    }

    func setInterval(_ callback: JSValue, _ ms: Double) -> String {
        return createTimer(callback: callback, ms: ms, repeats: true)
    }

    func clearInterval(_ identifier: String) {
        invalidateTimer(identifier: identifier)
    }

    private func createTimer(callback: JSValue, ms: Double, repeats: Bool) -> String {
        counter += 1
        let identifier = "\(counter)"

        DispatchQueue.main.async { [weak self] in
            let timer = Timer.scheduledTimer(withTimeInterval: ms / 1000, repeats: repeats) { _ in
                callback.call(withArguments: nil)
            }
            self?.timers[identifier] = timer
        }

        return identifier
    }

    private func invalidateTimer(identifier: String) {
        DispatchQueue.main.async { [weak self] in
            self?.timers[identifier]?.invalidate()
            self?.timers.removeValue(forKey: identifier)
        }
    }
}


extension JSCTimer {
    // Reference: https://stackoverflow.com/a/39864295
    static func register(context: JSContext) {
        let KS = "_timer"
        let timer = JSCTimer()
        context.setObject(timer, forKeyedSubscript: KS as (NSCopying & NSObjectProtocol))
        context.evaluateScript(
            "function setTimeout(callback, ms) {" +
            "    return _timer.setTimeout(callback, ms)" +
            "}" +
            "function clearTimeout(indentifier) {" +
            "    _timer.clearTimeout(indentifier)" +
            "}" +
            "function setInterval(callback, ms) {" +
            "    return _timer.setInterval(callback, ms)" +
            "}"
        )
    }
}
