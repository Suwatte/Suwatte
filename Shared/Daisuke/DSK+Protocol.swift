//
//  DSK+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-25.
//

import Foundation
import JavaScriptCore

protocol DaisukeInterface: Codable, Hashable, Identifiable {}

protocol DaisukeRunnerProtocol {
    var runnerClass: JSValue { get }
    var info: DaisukeRunnerInfoProtocol { get }
    var runnerType: DaisukeEngine.RunnerType { get }
}

extension DaisukeRunnerProtocol {
    var id: String {
        info.id
    }

    var name: String {
        info.name
    }
}

protocol DaisukeRunnerInfoProtocol: Parsable {
    var id: String { get }
    var name: String { get }
    var version: Double { get }
    var authors: [String]? { get }
    var minSupportedAppVersion: String? { get }
}

extension DaisukeEngine {
    enum RunnerType: Int, Codable {
        case CONTENT_SOURCE, SERVICE

        var description: String {
            switch self {
            case .CONTENT_SOURCE:
                return "Content Source"
            case .SERVICE:
                return "Service"
            }
        }
    }
}

extension DaisukeEngine {}
