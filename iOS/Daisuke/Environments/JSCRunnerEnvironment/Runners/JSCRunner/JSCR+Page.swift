//
//  JSCR+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

// MARK: - Page Resolver

extension JSCRunner: DSKPageDelegate {
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request {
        return try await callMethodReturningDecodable(method: "willRequestImage", arguments: [imageURL.absoluteString], resolvesTo: DSKCommon.Request.self)
    }

    func getSectionsForPage(link: DSKCommon.PageLink) async throws -> [DSKCommon.PageSection] {
        let pageLink = try link.asDictionary()
        return try await callMethodReturningDecodable(method: "getSectionsForPage", arguments: [pageLink], resolvesTo: [DSKCommon.PageSection].self)
    }

    func willResolveSectionsForPage(link: DSKCommon.PageLink) async throws {
        let pageLink = try link.asDictionary()
        try await callOptionalVoidMethod(method: "willResolveSectionsForPage", arguments: [pageLink])
    }

    func resolvePageSection(link: DSKCommon.PageLink, section: String) async throws -> DSKCommon.ResolvedPageSection {
        let pageLink = try link.asDictionary()
        return try await callMethodReturningDecodable(method: "resolvePageSection", arguments: [pageLink, section], resolvesTo: DSKCommon.ResolvedPageSection.self)
    }
}

// MARK: - Page Provider

extension JSCRunner {
    func getLibraryPageLinks() async throws -> [DSKCommon.PageLinkLabel] {
        try await callMethodReturningDecodable(method: "getLibraryPageLinks", arguments: [], resolvesTo: [DSKCommon.PageLinkLabel].self)
    }

    func getBrowsePageLinks() async throws -> [DSKCommon.PageLinkLabel] {
        try await callMethodReturningDecodable(method: "getBrowsePageLinks", arguments: [], resolvesTo: [DSKCommon.PageLinkLabel].self)
    }
}
