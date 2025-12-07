//
//  Runner+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

@globalActor actor RunnerActor: GlobalActor {
    static let shared = RunnerActor()
    static func run<T>(resultType _: T.Type = T.self, body: @Sendable () async throws -> T) async rethrows -> T where T: Sendable {
        try await body()
    }
}

protocol DSKRunnerDelegate {
    var info: RunnerInfo { get }
    var intents: RunnerIntents { get }
    var configCache: [String: DSKCommon.DirectoryConfig] { get set }
    var customID: String? { get }
    var customName: String? { get }

    func handleURL(url: String) async throws -> DSKCommon.DeepLinkContext?
}

protocol DSKPreferenceDelegate {
    func updatePreference(key: String, value: Any) async
    func getPreferenceMenu() async throws -> DSKCommon.Form
}

protocol DSKAuthDelegate {
    func getAuthenticatedUser() async throws -> DSKCommon.User?
    func handleUserSignOut() async throws
    func handleBasicAuthentication(id: String, password: String) async throws
    func getWebAuthRequestURL() async throws -> DSKCommon.BasicURL
    func didReceiveCookieFromWebAuthResponse(name: String) async throws -> DSKCommon.BooleanState
    func getOAuthRequestURL() async throws -> DSKCommon.BasicURL
    func handleOAuthCallback(response: String) async throws
}

protocol DSKDirectoryDelegate {
    func getDirectory(request: DSKCommon.DirectoryRequest) async throws -> DSKCommon.PagedResult
    func getDirectoryConfig(key: String?) async throws -> DSKCommon.DirectoryConfig
}

protocol DSKPageDelegate {
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request
    func getSectionsForPage(link: DSKCommon.PageLink) async throws -> [DSKCommon.PageSection]
    func willResolveSectionsForPage(link: DSKCommon.PageLink) async throws
    func resolvePageSection(link: DSKCommon.PageLink, section: String) async throws -> DSKCommon.ResolvedPageSection
    func getLibraryPageLinks() async throws -> [DSKCommon.PageLinkLabel]
    func getBrowsePageLinks() async throws -> [DSKCommon.PageLinkLabel]
}

protocol DSKSetupDelegate {
    func getSetupMenu() async throws -> DSKCommon.Form
    func validateSetupForm(form: DSKCommon.CodableDict) async throws
    func isRunnerSetup() async throws -> DSKCommon.BooleanState
}

extension DSKRunnerDelegate {
    var id: String {
        customID ?? info.id
    }

    var name: String {
        customName ?? info.name
    }

    var version: Double {
        info.version
    }

    var environment: RunnerEnvironment {
        self is AnyContentSource ? .source : self is AnyContentTracker ? .tracker : .unknown
    }
}

extension DSKRunnerDelegate {
    func saveState() {
        UserDefaults.standard.set(intents.imageRequestHandler, forKey: STTKeys.RunnerOverridesImageRequest(id))
        UserDefaults.standard.set(intents.pageLinkResolver, forKey: STTKeys.PageLinkResolver(id))
    }
}

protocol DSKRunner: DSKRunnerDelegate, DSKAuthDelegate, DSKPreferenceDelegate, DSKDirectoryDelegate, DSKPageDelegate, DSKSetupDelegate {}

typealias AnyRunner = (any DSKRunner)
typealias DSK = DaisukeEngine
typealias DSKCommon = DaisukeEngine.Structs
