//
//  Realm+IceCream.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-16.
//

import IceCream
import RealmSwift

extension RealmActor {
    func getObject<T: Object>(of _: T.Type, with key: String) -> T? where T: CKRecordConvertible, T: CKRecordRecoverable {
        let target = realm
            .object(ofType: T.self, forPrimaryKey: key)

        guard let target, !target.isDeleted else {
            return nil
        }
        return target
    }
}
