//
//  DSK+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import Foundation
import AnyCodable

// Reference: https://acecilia.medium.com/struct-composition-using-keypath-and-dynamicmemberlookup-kind-of-struct-subclassing-but-better-6ce561768612
@dynamicMemberLookup
struct Compose<Element1, Element2>: Codable where Element1: Codable, Element2: Codable {
    var element1: Element1
    var element2: Element2
    subscript<T>(dynamicMember keyPath: WritableKeyPath<Element1, T>) -> T {
        get { element1[keyPath: keyPath] }
        set { element1[keyPath: keyPath] = newValue }
    }
    subscript<T>(dynamicMember keyPath: WritableKeyPath<Element2, T>) -> T {
        get { element2[keyPath: keyPath] }
        set { element2[keyPath: keyPath] = newValue }
    }
    init(_ element1: Element1, _ element2: Element2) {
        self.element1 = element1
        self.element2 = element2
    }
}

extension DSKCommon {
    enum SectionStyle: Int, Codable, CaseIterable {
        case   DEFAULT,
               INFO,
               GALLERY,
               NAVIGATION_LIST,
               ITEM_LIST,
               PADDED_LIST,
               TAG,
               STANDARD_GRID
    }
}

typealias JSCObject = Parsable & Hashable
extension DSKCommon {
        
    struct PageSection<T: JSCObject>: JSCObject {
        let key: String
        var title: String
        let style: SectionStyle?
        var subtitle: String?
        var viewMoreLink: Linkable?
        var items: [PageItem<T>]?
        
        var sectionStyle: SectionStyle {
            style ?? .DEFAULT
        }
    }
    
    struct ResolvedPageSection<T: JSCObject> :JSCObject{
        let items: [PageItem<T>]
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
    
    struct PageLink: JSCObject  {
        let key: String
        let context: CodableDict?
    }
    
    struct PageItem<T: JSCObject>: JSCObject {
        let link: PageLinkLabel?
        let item: T?
        var isValidItem: Bool {
            link != nil || item != nil
        }
    }
}



extension DSKCommon {
    struct Linkable: Parsable , Hashable {
        let page: PageLink?
        let request: DirectoryRequest?

        var isPageLink: Bool {
            page != nil
        }
        
        func getPageLink() -> PageLink {
            .init(key: page?.key ?? "home", context: page?.context ?? nil)
        }
        
        func getDirectoryRequest() -> DirectoryRequest {
            request!
        }
    }
}
