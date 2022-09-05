//
//  STT+Realm.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-09.
//

import RealmSwift

//
extension RealmSwift.List {
    func toArray() -> [Element] {
        return compactMap {
            $0
        }
    }
}

extension Results {
    func toArray() -> [Element] {
        return compactMap {
            $0
        }
    }
}

// Reference: https://github.com/realm/realm-swift/issues/4511#issuecomment-270962198
public extension Realm {
    func safeWrite(_ block: () throws -> Void) throws {
        if isInWriteTransaction {
            try block()
        } else {
            try write(block)
        }
    }
}
