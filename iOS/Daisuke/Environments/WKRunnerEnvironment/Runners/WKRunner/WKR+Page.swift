//
//  WKR+Page.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation


extension WKRunner : DSKPageDelegate {
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request {
        try await eval(script("let data = await RunnerObject.willRequestImage(url)"),
                       ["url": imageURL.absoluteString])
    }
    
    func getSectionsForPage<T>(link: DSKCommon.PageLink) async throws -> [DaisukeEngine.Structs.PageSection<T>] where T : Parsable, T : Hashable {
        try await eval(script("let data = await RunnerObject.getSectionsForPage(link)"),
                       ["link": try link.asDictionary()])
    }
    
    func willResolveSectionsForPage(link: DSKCommon.PageLink) async throws {
        let script = """
            if (!RunnerObject.willResolveSectionsForPage) return;
            await RunnerObject.willResolveSectionsForPage(link);
        """
        try await eval(script,
                       ["link": try link.asDictionary()])
    }
    
    func resolvePageSection<T>(link: DSKCommon.PageLink, section: String) async throws -> DaisukeEngine.Structs.ResolvedPageSection<T> where T : Parsable, T : Hashable {
        try await eval(script("let data = await RunnerObject.resolvePageSection(link, section)"),
                       ["link": try link.asDictionary(), "section": section])
    }
    
    func getLibraryPageLinks() async throws -> [DSKCommon.PageLinkLabel] {
       try await eval(script("let data = await RunnerObject.getLibraryPageLinks()"))
    }
    
    func getBrowsePageLinks() async throws -> [DSKCommon.PageLinkLabel] {
        try await eval(script("let data = await RunnerObject.getBrowsePageLinks()"))
    }
}
