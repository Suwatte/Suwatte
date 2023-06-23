//
//  SauceNao.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Alamofire
import Foundation
import UIKit

final class SauceNao {
    static var shared = SauceNao()

    private var key = "b1e601ed339f1c909df951a2ebfe597671592d90"

    private let host = "https://saucenao.com/search.php"

    private var url: URL {
        var components = URLComponents(string: host)

        components?.queryItems = [
            .init(name: "output_type", value: "2"),
            .init(name: "numres", value: "10"),
            .init(name: "api_key", value: key),
            .init(name: "db", value: "37"),
        ]

        return components!.url!
    }

    func search(with image: UIImage) async throws -> Response {
        let request = AF.upload(multipartFormData: { data in
            if let imageData = image.jpegData(compressionQuality: 1) {
                data.append(imageData, withName: "file", fileName: "file.png", mimeType: "image/png")
            }

        }, to: url, method: .post)

        let value = try await request.serializingDecodable(Response.self).value

        return value
    }
}

extension SauceNao {
    struct Response: Decodable {
        var results: [Entry]
    }

    struct Entry: Decodable {
        var header: EntryHeader
        var data: EntryData
    }

    struct EntryHeader: Decodable {
        var similarity: String
        var thumbnail: String
        var index_name: String
    }

    struct EntryData: Decodable {
        var ext_urls: [String]
        var md_id: String
        var mu_id: Int?
        var mal_id: Int?
        var source: String
        var part: String
        var artist: String
        var author: String
    }
}
