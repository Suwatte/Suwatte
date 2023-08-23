//
//  Runner+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

@globalActor actor RunnerActor: GlobalActor {
    static var shared = RunnerActor()
    public static func run<T>(resultType: T.Type = T.self, body: @Sendable () throws -> T) async rethrows -> T where T : Sendable {
        try body()
    }
}

struct InstanceInformation {
    let name: String
    let id: String
}

protocol DSKRunnerDelegate {
    var info: RunnerInfo { get }
    var instance: InstanceInformation { get }
    var intents: RunnerIntents { get }
    var configCache: [String: DSKCommon.DirectoryConfig] { get set }
}

protocol DSKPreferenceDelegate {
    func updateSourcePreference(key: String, value: Any) async
    func buildPreferenceMenu() async throws -> [DSKCommon.PreferenceGroup]
}

protocol DSKAuthDelegate {
    func getAuthenticatedUser() async throws -> DSKCommon.User?
    func handleUserSignOut() async throws
    func handleBasicAuthentication(id: String, password: String) async throws
    func getWebAuthRequestURL() async throws -> DSKCommon.BasicURL
    func didReceiveCookieFromWebAuthResponse(name: String) async throws -> Bool
    func getOAuthRequestURL() async throws -> DSKCommon.BasicURL
    func handleOAuthCallback(response: String) async throws
}

protocol DSKDirectoryDelegate {
    func getDirectory<T: Codable>(request: DSKCommon.DirectoryRequest) async throws -> DSKCommon.PagedResult<T>
    func getDirectoryConfig(key: String?) async throws -> DSKCommon.DirectoryConfig
}

protocol DSKPageDelegate {
    func willRequestImage(imageURL: URL) async throws -> DSKCommon.Request
    func getSectionsForPage<T: JSCObject>(link: DSKCommon.PageLink) async throws -> [DSKCommon.PageSection<T>]
    func willResolveSectionsForPage(link: DSKCommon.PageLink) async throws
    func resolvePageSection<T: JSCObject>(link: DSKCommon.PageLink, section: String) async throws -> DSKCommon.ResolvedPageSection<T>
    func getLibraryPageLinks() async throws -> [DSKCommon.PageLinkLabel]
    func getBrowsePageLinks() async throws -> [DSKCommon.PageLinkLabel]
}


extension DSKRunnerDelegate {
    var runnerID: String {
        info.id
    }
    
    var id: String {
        info.id
    }
    
    var instanceID: String {
        info.id + "::" + instance.id
    }

    var name: String {
        info.name
    }

    var version: Double {
        info.version
    }
    
    var environment: RunnerEnvironment {
        self is ContentSource ? .source : self is ContentTracker ? .tracker : .unknown
    }
}


extension DSKRunnerDelegate {
    func saveState() {
        UserDefaults.standard.set(intents.imageRequestHandler, forKey: STTKeys.RunnerOverridesImageRequest(id))
        UserDefaults.standard.set(intents.pageLinkResolver, forKey: STTKeys.PageLinkResolver(id))
    }
}


protocol DSKRunner: DSKRunnerDelegate, DSKAuthDelegate, DSKPreferenceDelegate, DSKDirectoryDelegate, DSKPageDelegate {}

typealias AnyRunner = (any DSKRunner)
typealias DSK = DaisukeEngine
typealias DSKCommon = DaisukeEngine.Structs
