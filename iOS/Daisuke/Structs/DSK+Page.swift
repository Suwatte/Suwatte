//
//  DSK+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import AnyCodable
import Foundation

extension DSKCommon {
    enum SectionStyle: Int, Codable, CaseIterable {
        case DEFAULT,
             INFO,
             GALLERY,
             NAVIGATION_LIST,
             ITEM_LIST,
             PADDED_LIST,
             TAG,
             STANDARD_GRID
    }
}

typealias JSCObject = Hashable & Parsable
extension DSKCommon {
    struct PageSection : JSCObject {
        let id: String
        var title: String
        let style: SectionStyle?
        var subtitle: String?
        var viewMoreLink: Linkable?
        var items: [Highlight]?

        var sectionStyle: SectionStyle {
            style ?? .DEFAULT
        }
    }

    struct ResolvedPageSection: JSCObject {
        let items: [Highlight]
        let viewMoreLink: Linkable?
        let updatedTitle: String?
        let updatedSubtitle: String?
    }

    struct PageLinkLabel: JSCObject {
        let title: String
        let subtitle: String?
        let badge: Badge?
        let cover: String?
        let link: Linkable
    }

    struct PageLink: JSCObject {
        let id: String
        let context: CodableDict?
    }
}

extension DSKCommon {
    struct Linkable: Parsable, Hashable {
        let page: PageLink?
        let request: DirectoryRequest?

        var isPageLink: Bool {
            page != nil
        }

        func getPageLink() -> PageLink {
            .init(id: page?.id ?? "home", context: page?.context ?? nil)
        }

        func getDirectoryRequest() -> DirectoryRequest {
            request!
        }
    }
}

extension DSKCommon {
    struct ContextMenuGroup: JSCObject {
        let id: String
        let actions: [ContextMenuAction]
    }

    struct ContextMenuAction: JSCObject {
        let id: String
        let title: String
        let systemImage: String?
        let destructive: Bool?
        let displayAsPlainLabel: Bool?

        var displayAsLabel: Bool {
            displayAsPlainLabel ?? false
        }

        var isDestructive: Bool {
            destructive ?? false
        }
    }
}
