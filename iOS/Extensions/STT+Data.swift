//
//  STT+Data.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-16.
//

import Foundation

extension Data {
    func toString() -> String {
        String(decoding: self, as: UTF8.self)
    }
}
