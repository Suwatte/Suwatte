//
//  Daisuke.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Alamofire
import Foundation
import JavaScriptCore
import RealmSwift

final class DaisukeEngine: ObservableObject {
    // MARK: Singleton
    static let shared = DaisukeEngine()
}

extension JSContext {
    func daisukeRunner() -> JSValue? {
        return evaluateScript("(function(){ return DAISUKE_RUNNER })()")
    }
}

