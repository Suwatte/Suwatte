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

    func getSectionsForPage<T: JSCObject>(link: DSKCommon.PageLink) async throws -> [DSKCommon.PageSection<T>] {
        let pageLink = try link.asDictionary()
        return try await callMethodReturningDecodable(method: "getSectionsForPage", arguments: [pageLink], resolvesTo: [DSKCommon.PageSection<T>].self)
    }

    func willResolveSectionsForPage(link: DSKCommon.PageLink) async throws {
        let pageLink = try link.asDictionary()
        try await callOptionalVoidMethod(method: "willResolveSectionsForPage", arguments: [pageLink])
    }

    func resolvePageSection<T: JSCObject>(link: DSKCommon.PageLink, section: String) async throws -> DSKCommon.ResolvedPageSection<T> {
        let pageLink = try link.asDictionary()
        return try await callMethodReturningDecodable(method: "resolvePageSection", arguments: [pageLink, section], resolvesTo: DSKCommon.ResolvedPageSection<T>.self)
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
