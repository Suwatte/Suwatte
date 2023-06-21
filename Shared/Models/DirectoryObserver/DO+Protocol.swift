//
//  DO+Protocol.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import CryptoKit
struct File: Identifiable {
    let url: URL
    let isOnDevice: Bool
    let id: String
    
    // Properties
    let name: String
    let created: Date
    let size: Int64
}


struct Folder {
    let url: URL
    var files: [File] = []
    var folders: [SubFolder] = []
    
    struct SubFolder : Identifiable{
        let url: URL
        let id: String
    }
}


protocol DirectoryObserver {
    func observe(_ callback: @escaping ((Folder) -> Void))
    func stop() -> Void
    
    var path: URL { get }
    var extensions: [String] { get }
}


extension DirectoryObserver {
    
    func generateFileIdentifier(size: Int64, created: Date, modified: Date) -> String {
        let sizeHash = sha256(of: "\(size)")
        let createdHash = sha256(of: "\(created)")
        let modifiedHash = sha256(of: "\(modified)")
        
        let combinedHash = sizeHash + createdHash + modifiedHash
        return sha256(of: combinedHash)
    }
    
    func generateFolderIdentifier(created: Date) -> String {
        return sha256(of: "\(created)")
    }
    
    private func sha256(of string: String) -> String {
        let data = string.data(using: .utf8)!
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
