//
//  STTImageProvider.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Foundation
import UIKit

final actor STTImageProvider {
    static let shared = STTImageProvider()

    static let directory = FileManager.default.documentDirectory.appendingPathComponent("Thumbnails", isDirectory: true)

    init() {
        Self.directory.createDirectory()
    }

    func saveImage(_ image: UIImage, for indentifier: String) throws -> URL {
        let filename = indentifier.appending(".jpg")
        let filepath = Self.directory.appendingPathComponent(filename)

        try image.jpegData(compressionQuality: 1.0)?.write(to: filepath, options: .atomic)
        return filepath
    }

    func urlFor(id: String) -> URL {
        Self.directory.appendingPathComponent("\(id).jpg")
    }
}
