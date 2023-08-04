//
//  JSC+RunnerIntents.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

struct RunnerIntents: Parsable {
    let preferenceMenuBuilder: Bool

    let authenticatable: Bool
    let authenticationMethod: AuthenticationMethod
    let basicAuthLabel: BasicAuthenticationUIIdentifier?
    let imageRequestHandler: Bool
    let pageLinkResolver: Bool
    let libraryPageLinkProvider: Bool
    let browsePageLinkProvider: Bool

    // JSCCS
    let chapterEventHandler: Bool
    let contentEventHandler: Bool
    let chapterSyncHandler: Bool
    let librarySyncHandler: Bool
    let hasTagsView: Bool

    // MSB
    let pageReadHandler: Bool
    let providesReaderContext: Bool
    let canRefreshHighlight: Bool

    // Context Menu
    let isContextMenuProvider: Bool

    // JSC CT
    let advancedTracker: Bool

    enum AuthenticationMethod: String, Codable {
        case webview, basic, oauth, unknown
    }

    enum BasicAuthenticationUIIdentifier: Int, Codable {
        case EMAIL
        case USERNAME
    }
}