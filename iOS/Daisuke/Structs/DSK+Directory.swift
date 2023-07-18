//
//  DSK+Directory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import Foundation
import AnyCodable

extension DSKCommon {
    
    enum FilterType: Int, Codable {
        case toggle, select, multiselect, excludableMultiselect, text, info
    }
    
    struct Option: Parsable, Hashable, Identifiable {
        let key: String
        let label: String
        
        var id: String {
            key
        }
    }
    
    struct DirectoryConfig: Parsable, Hashable {
        let sortOptions: [Option]?
        let filters: [DirectoryFilter]?
    }
    
    struct DirectoryFilter: Parsable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        let label: String?
        let type: FilterType
        let options: [Option]?
    }
    
    struct ExcludableMultiSelectProp: Parsable {
        var included: Set<String>
        var excluded: Set<String>
    }
    
    struct DirectoryRequest: Parsable, Hashable {
        var query: String?
        var page: Int
        var sortKey: String?
        var filters: [String: AnyCodable]?
        var tag: RequestTag?
        var custom: [String: AnyCodable]?
        var configKey: String?
        
        struct RequestTag: Parsable, Hashable {
            var tagId: String
            var propertyId: String
        }
    }
    
    struct PagedResult<T>: Codable, Hashable where T: Codable, T: Hashable {
        var results: [T]
        var isLastPage: Bool
        var totalResultCount: Int?
    }
    

    struct HighlightCollection: Parsable, Identifiable, Hashable {
        var id: String
        var title: String
        var subtitle: String?
        var request: DirectoryRequest?
        var highlights: [DSKCommon.Highlight]
    }
}
