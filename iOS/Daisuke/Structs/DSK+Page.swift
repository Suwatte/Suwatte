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
        case NORMAL, INFO, GALLERY, UPDATE_LIST, TAG

        var description: String {
            switch self {
            case .NORMAL: return "Normal"
            case .INFO: return "Info"
            case .GALLERY: return "Gallery"
            case .UPDATE_LIST: return "Update"
            case .TAG: return "Tag"
            }
        }
    }
}
extension DSKCommon {
        
    struct Page: Parsable, Hashable {
        let key: String
        let sections: [PageSection]
        
    }
    
    struct PageSection: Parsable, Hashable {
        let key: String
        var title: String
        let style: SectionStyle?
        var subtitle: String?
        var viewMoreLink: Linkable?
        var items: [PageSectionItem]?
        
        var sectionStyle: SectionStyle {
            style ?? .NORMAL
        }
    }
    
    struct ResolvedPageSection: Parsable, Hashable {
        let items: [PageSectionItem]
        let viewMoreLink: Linkable?
        let updatedTitle: String?
        let updatedSubtitle: String?
    }
    
    struct PageLink: Parsable, Hashable {
        let label: String
        let thumbnail: String?
        let link: Linkable
    }
    
    struct PageItem : Parsable, Hashable {
        let id: String
        let title: String
        let cover: String
        let additionalCovers: [String]?
        let info: [String]?
        let trackStatus: DSKCommon.TrackStatus?
        let badgeColor: String?
    }
}



extension DSKCommon {
    struct Linkable: Parsable , Hashable { // Combination of DirectoryRequest && { pageKey: String }
        let pageKey: String?
        var query: String?
        var page: Int?
        var sortKey: String?
        var filters: [String: AnyCodable]?
        var tag: DirectoryRequest.RequestTag?
        var custom: [String: AnyCodable]?
        
        var isPageLink: Bool {
            pageKey != nil
        }
        
        func getPageKey() -> String {
            pageKey ?? "home"
        }
        
        func getDirectoryRequest() -> DirectoryRequest {
            .init(query: query, page: page ?? 1, sortKey: sortKey, filters: filters, tag: tag, custom: custom)
        }
    }
}


extension DSKCommon {
    
    /// This struct is a combination of a PageLInk and a PageItem, as the JS Equivalent allows both to be passed and rendered as seen fit
    struct PageSectionItem: Parsable, Hashable {
        let id: String?
        let title: String?
        let cover: String?
        let thumbnail: String?
        let additionalCovers: [String]?
        let info: [String]?
        let label: String?
        let link: Linkable?
        let trackStatus: DSKCommon.TrackStatus?
        let badgeColor: String?
        
        var isPageLink : Bool {
            link != nil
        }
        
        func toPageLink() -> PageLink {
            .init(label: label ?? "", thumbnail: thumbnail, link: link ?? .init(pageKey: ""))
        }
        
        func toPageItem() -> PageItem {
            .init(id: id ?? "", title: title ?? "", cover: cover ?? "", additionalCovers: additionalCovers, info: info, trackStatus: trackStatus, badgeColor: badgeColor)
        }
        
        var imageUrl : String {
            cover ?? thumbnail ?? ""
        }
    }
}
