//
//  WKR+Directory.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation


extension WKRunner: DSKDirectoryDelegate {
    func getDirectory<T>(request: DSKCommon.DirectoryRequest) async throws -> DaisukeEngine.Structs.PagedResult<T> where T : Decodable, T : Encodable, T : Hashable {
        let args = ["request": try request.asDictionary()]
        return try await eval(script("let data = await RunnerObject.getDirectory(request)"), args)
    }
    
    func getDirectoryConfig(key: String?) async throws -> DSKCommon.DirectoryConfig {
        if let config = configCache[key ?? "default"] {
            return config
        }
        let data: DSKCommon.DirectoryConfig = try await eval(script("let data = await RunnerObject.getDirectoryConfig(key)"), ["key": key as Any])
        configCache[key ?? "default"] = data
        return data

    }    
}
