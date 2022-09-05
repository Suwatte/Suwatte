//
//  AL+Error.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Foundation

extension Anilist {
    enum AnilistError: Error {
        case NotAuthenticated
        case FailedToParse
    }
}
