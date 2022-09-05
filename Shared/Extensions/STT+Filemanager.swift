//
//  STT+Filemanager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation

extension FileManager {
    var documentDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var libraryDirectory: URL {
        urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }
}
