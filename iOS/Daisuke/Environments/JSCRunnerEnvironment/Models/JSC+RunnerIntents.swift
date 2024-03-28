//
//  JSC+RunnerIntents.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

struct RunnerIntents: Parsable, Hashable {
    let preferenceMenuBuilder: Bool

    let authenticatable: Bool
    let authenticationMethod: AuthenticationMethod
    let basicAuthLabel: BasicAuthenticationUIIdentifier?
    let imageRequestHandler: Bool
    let pageLinkResolver: Bool
    let libraryPageLinkProvider: Bool
    let browsePageLinkProvider: Bool

    // CS
    let chapterEventHandler: Bool
    let contentEventHandler: Bool
    let librarySyncHandler: Bool
    let hasTagsView: Bool

    // MSB
    let pageReadHandler: Bool
    let providesReaderContext: Bool
    let canRefreshHighlight: Bool

    // Context Menu
    let isContextMenuProvider: Bool

    // CT
    let advancedTracker: Bool

    // Setup
    let requiresSetup: Bool

    enum AuthenticationMethod: String, Codable, Hashable {
        case webview, basic, oauth, unknown
    }

    let canHandleURL: Bool?
    let progressSyncHandler: Bool?
    let groupedUpdateFetcher: Bool?

    // Redraw
    let isRedrawingHandler: Bool?

    enum BasicAuthenticationUIIdentifier: Int, Codable {
        case EMAIL
        case USERNAME
    }
}


extension RunnerIntents {
    static var placeholder : Self {
        .init(preferenceMenuBuilder: false, authenticatable: false, authenticationMethod: .unknown, basicAuthLabel: nil, imageRequestHandler: false, pageLinkResolver: false, libraryPageLinkProvider: false, browsePageLinkProvider: false, chapterEventHandler: false, contentEventHandler: false, librarySyncHandler: false, hasTagsView: false, pageReadHandler: false, providesReaderContext: false, canRefreshHighlight: false, isContextMenuProvider: false, advancedTracker: false, requiresSetup: false, canHandleURL: false, progressSyncHandler: false, groupedUpdateFetcher: false, isRedrawingHandler: false)
    }
}
