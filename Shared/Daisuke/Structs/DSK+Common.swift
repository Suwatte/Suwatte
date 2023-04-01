//
//  DSK+Common.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-10-02.
//

import Foundation

extension DSKCommon {
    struct JSCommon: Codable {
        var version: String
    }
}

extension DSKCommon {
    enum AuthMethod: Int, Codable {
        case username_pw, email_pw, web, oauth

        var isBasic: Bool {
            self == .username_pw || self == .email_pw
        }
    }

    struct User: Parsable, Hashable {
        var id: String
        var username: String
        var avatar: String?
        var info: [String]?
    }
}
