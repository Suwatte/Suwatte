//
//  Backup+Runner.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-31.
//

import Foundation

extension StoredRunnerList: Codable {
    enum Keys: String, CodingKey {
        case listName, url
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        listName = try container.decodeIfPresent(String.self, forKey: .listName)
        url = try container.decode(String.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(listName, forKey: .listName)
        try container.encode(url, forKey: .url)
    }
}

extension StoredRunnerObject: Codable {
    enum Keys: String, CodingKey {
        case id, parentRunnerID, name, version, environment, enabled, listURL, thumbnail, isLibraryPageLinkProvider, isBrowsePageLinkProvider
    }

    convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        listURL = try container.decodeIfPresent(String.self, forKey: .listURL) ?? ""
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail) ?? ""
        parentRunnerID = try container.decodeIfPresent(String.self, forKey: .parentRunnerID)
        version = try container.decode(Double.self, forKey: .version)
        environment = try container.decodeIfPresent(RunnerEnvironment.self, forKey: .environment) ?? .unknown
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        isLibraryPageLinkProvider = try container.decodeIfPresent(Bool.self, forKey: .isLibraryPageLinkProvider) ?? false
        isBrowsePageLinkProvider = try container.decodeIfPresent(Bool.self, forKey: .isBrowsePageLinkProvider) ?? false
        dateAdded = .now
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(listURL, forKey: .listURL)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(parentRunnerID, forKey: .parentRunnerID)
        try container.encode(environment, forKey: .environment)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(isLibraryPageLinkProvider, forKey: .isLibraryPageLinkProvider)
        try container.encode(isBrowsePageLinkProvider, forKey: .isBrowsePageLinkProvider)
        try container.encode(version, forKey: .version)
    }
}
