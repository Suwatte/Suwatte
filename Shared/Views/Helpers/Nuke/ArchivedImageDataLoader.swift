//
//  ArchivedImageDataLoader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-25.
//

import Foundation
import Nuke
import Unrar
import ZIPFoundation

final class ArchivedImageDataLoader: Nuke.DataLoading {
    init(for id: Int64, ofName name: String) {
        self.id = id
        fileName = name
    }

    let id: Int64
    let fileName: String
    typealias LCM = LocalContentManager

    func loadData(with _: URLRequest, didReceiveData: @escaping (Data, URLResponse) -> Void, completion: @escaping (Error?) -> Void) -> Cancellable {
        let task = Task {
            let manager = LCM.shared

            do {
                guard let path = manager.idHash[id]?.url else {
                    throw LCM.Errors.DNE
                }
                try Task.checkCancellation()

                switch path.pathExtension {
                case "cbz":
                    guard let archive = ZIPFoundation.Archive(url: path, accessMode: .read), let file = archive.first(where: { $0.path == fileName }) else {
                        throw LCM.Errors.DNE
                    }
                    try Task.checkCancellation()
                    var out = Data()

                    _ = try archive.extract(file) { data in
                        try Task.checkCancellation()
                        out.append(data)
                    }
                    let response = URLResponse(url: URL(string: "https://www.stt_local/\(id)/\(fileName)") ?? STTHost.notFound, mimeType: "image/png", expectedContentLength: out.count, textEncodingName: nil)
                    didReceiveData(out, response)
                case "cbr":
                    let archive = try Unrar.Archive(fileURL: path)
                    try Task.checkCancellation()
                    let entries = try archive.entries()
                    let entry = entries.first(where: {
                        $0.fileName == fileName
                    })
                    try Task.checkCancellation()

                    guard let entry = entry else {
                        throw LCM.Errors.DNE
                    }
                    try Task.checkCancellation()
                    let data = try archive.extract(entry)
                    let response = URLResponse(url: URL(string: "https://www.stt_local.com/\(id)/\(fileName)") ?? STTHost.notFound, mimeType: "image/jpeg", expectedContentLength: data.count, textEncodingName: nil)
                    print(response.url)
                    didReceiveData(data, response)

                default: break
                }

                throw LCM.Errors.InvalidType

            } catch {
                completion(error)
            }

            completion(nil)
        }

        return AnyCancellable {
            task.cancel()
        }
    }
}

private final class AnyCancellable: Nuke.Cancellable {
    let closure: @Sendable () -> Void

    init(_ closure: @Sendable @escaping () -> Void) {
        self.closure = closure
    }

    func cancel() {
        closure()
    }
}
