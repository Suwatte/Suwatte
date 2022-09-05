//
//  RawImageDataLoader.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-25.
//

import Foundation
import Nuke

final class RawImageDataLoader: Nuke.DataLoading {
    init(raw: String) {
        self.raw = raw
    }

    let raw: String
    func loadData(with _: URLRequest, didReceiveData: @escaping (Data, URLResponse) -> Void, completion: @escaping (Error?) -> Void) -> Cancellable {
        let task = Task {
            let response = URLResponse()
            let data = Data(base64Encoded: raw.toBase64())
            var error: Error?
            if let data = data {
                didReceiveData(data, response)
            } else {
                error = DSK.Errors.NamedError(name: "Conversion Failure", message: "Invalid Data String")
            }
            completion(error)
        }

        return AnyCancellable {
            task.cancel()
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
}
