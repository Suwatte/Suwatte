//
//  STT+OPDS.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-14.
//

import Alamofire
import Foundation
import Fuzi
import R2Shared
import ReadiumOPDS

struct MimeTypeParameters {
    var type: String
    var parameters = [String: String]()
}

class OPDSClient: ObservableObject {
    var baseUrl: String
    var id: String

    var authHeader: String?

    init(id: String, base: String, auth: (username: String, password: String)?) {
        self.id = id
        authHeader = nil
        baseUrl = base
        if let auth = auth {
            authHeader = generateAuthHeader(username: auth.username, password: auth.password)
        }
    }

    private func generateAuthHeader(username: String, password: String) -> String {
        let merge = "\(username):\(password)"
        return "Basic \(merge.toBase64())"
    }

    // Reference: https://stackoverflow.com/a/68696069
    private func request(url: URL) async throws -> Data {
        try await withUnsafeThrowingContinuation { continuation in
            var headers: HTTPHeaders = [:]
            if let auth = authHeader {
                headers.add(.init(name: "Authorization", value: auth))
            }

            AF.request(url, headers: headers).validate().responseData { response in
                if let data = response.data {
                    continuation.resume(returning: data)
                    return
                }
                if let err = response.error {
                    continuation.resume(throwing: err)
                    return
                }
                fatalError("Invalid Path, Should Never Reach")
            }
        }
    }

    func D2X(_ data: Data) throws -> XMLDocument {
        try XMLDocument(data: data)
    }

    func getFeed(url: String) async throws -> Feed {
        guard let url = URL(string: url) else {
            throw OPDSParserError.documentNotValid
        }
        let data = try await request(url: url)
        let xml = try D2X(data)
        return try OPDSLocalParser.parse(document: xml, feedURL: url)
    }
}

// Modified Version of the swift-toolkit OPDSParser Class
// Changes were made to work with the OPDS Page Streaming Extension 1.2
// TODO: This Impl can be a lot cleaner, look into it
/**
 BSD 3-Clause License

 Copyright (c) 2017, Readium
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

 * Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **/
class OPDSLocalParser: Loggable {
    /// Parse an OPDS feed.
    /// Feed can only be v1 (XML).
    /// - parameter document: The XMLDocument data
    /// - Returns: The resulting Feed
    static func parse(document: Fuzi.XMLDocument, feedURL: URL) throws -> Feed {
        document.definePrefix("thr", forNamespace: "http://purl.org/syndication/thread/1.0")
        document.definePrefix("dcterms", forNamespace: "http://purl.org/dc/terms/")
        document.definePrefix("opds", forNamespace: "http://opds-spec.org/2010/catalog")
        document.definePrefix("pse", forNamespace: "http://vaemendis.net/opds-pse/ns")

        guard let root = document.root else {
            throw OPDS1ParserError.rootNotFound
        }

        guard let title = root.firstChild(tag: "title")?.stringValue else {
            throw OPDS1ParserError.missingTitle
        }
        let feed = Feed(title: title)

        if let tmpDate = root.firstChild(tag: "updated")?.stringValue,
           let date = tmpDate.dateFromISO8601
        {
            feed.metadata.modified = date
        }
        if let totalResults = root.firstChild(tag: "TotalResults")?.stringValue {
            feed.metadata.numberOfItem = Int(totalResults)
        }
        if let itemsPerPage = root.firstChild(tag: "ItemsPerPage")?.stringValue {
            feed.metadata.itemsPerPage = Int(itemsPerPage)
        }

        for entry in root.children(tag: "entry") {
            var isNavigation = true
            var collectionLink: Link?

            for link in entry.children(tag: "link") {
                if let rel = link.attributes["rel"] {
                    // Check is navigation or acquisition.
                    if rel.range(of: "http://opds-spec.org/acquisition") != nil {
                        isNavigation = false
                    }

                    // Check if there is a collection.
                    if rel == "collection" || rel == "http://opds-spec.org/group",
                       let href = link.attributes["href"],
                       let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL)
                    {
                        collectionLink = Link(
                            href: absoluteHref,
                            title: link.attributes["title"],
                            rel: .collection
                        )
                    }
                }
            }

            if !isNavigation {
                if let publication = parseEntry(entry: entry, feedURL: feedURL) {
                    // Checking if this publication need to go into a group or in publications.
                    if let collectionLink = collectionLink {
                        addPublicationInGroup(feed, publication, collectionLink)
                    } else {
                        feed.publications.append(publication)
                    }
                }

            } else if let link = entry.firstChild(tag: "link"),
                      let href = link.attr("href"),
                      let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL)
            {
                var properties: [String: Any] = [:]
                if let facetElementCount = link.attr("count").map(Int.init) {
                    properties["numberOfItems"] = facetElementCount
                }

                let newLink = Link(
                    href: absoluteHref,
                    type: link.attr("type"),
                    title: entry.firstChild(tag: "title")?.stringValue,
                    rel: link.attr("rel").map { LinkRelation($0) },
                    properties: .init(properties)
                )

//                 Check collection link
                if let collectionLink = collectionLink {
                    addNavigationInGroup(feed, newLink, collectionLink)
                } else {
                    feed.navigation.append(newLink)
                }
            }
        }

        for link in root.children(tag: "link") {
            guard let href = link.attributes["href"], let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL) else {
                continue
            }

            var rels: [LinkRelation] = []
            if let rel = link.attributes["rel"], !rel.isEmpty {
                rels.append(.init(rel))
            }
            var properties: [String: Any] = [:]

            let isFacet = rels.contains(.opdsFacet)
            if isFacet {
                // Active Facet Check
                if link.attr("activeFacet")?.lowercased() == "true" {
                    rels.append(.self)
                }

                if let facetElementCount = link.attr("count").map(Int.init) {
                    properties["numberOfItems"] = facetElementCount
                }
            }

            let newLink = Link(
                href: absoluteHref,
                type: link.attributes["type"],
                title: link.attributes["title"],
                rels: rels,
                properties: .init(properties)
            )

            if isFacet {
                if let facetGroupName = link.attributes["facetGroup"] {
                    addFacet(feed: feed, to: newLink, named: facetGroupName)
                }
            } else {
                feed.links.append(newLink)
            }
        }

        return feed
    }

    /// Parse an OPDS publication.
    /// Publication can only be v1 (XML).
    /// - parameter document: The XMLDocument data
    /// - Returns: The resulting Publication
    static func parseEntry(document: Fuzi.XMLDocument, feedURL: URL) throws -> Publication? {
        guard let root = document.root else {
            throw OPDS1ParserError.rootNotFound
        }
        return parseEntry(entry: root, feedURL: feedURL)
    }

    /// Fetch an Open Search template from an OPDS feed.
    /// - parameter feed: The OPDS feed
    static func fetchOpenSearchTemplate(feed: Feed, completion: @escaping (String?, Error?) -> Void) {
        guard let openSearchHref = feed.links.first(withRel: .search)?.href,
              let openSearchURL = URL(string: openSearchHref)
        else {
            completion(nil, OPDSParserOpenSearchHelperError.searchLinkNotFound)
            return
        }

        URLSession.shared.dataTask(with: openSearchURL) { data, _, error in
            guard let data = data else {
                completion(nil, error ?? OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            guard let document = try? XMLDocument(data: data) else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            guard let urls = document.root?.children(tag: "Url") else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            if urls.count == 0 {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }
            // The OpenSearch document may contain multiple Urls, and we need to find the closest matching one.
            // We match by mimetype and profile; if that fails, by mimetype; and if that fails, the first url is returned
            var typeAndProfileMatch: Fuzi.XMLElement?
            var typeMatch: Fuzi.XMLElement?
            if let selfMimeType = feed.links.first(withRel: .self)?.type {
                let selfMimeParams = parseMimeType(mimeTypeString: selfMimeType)
                for url in urls {
                    guard let urlMimeType = url.attributes["type"] else {
                        continue
                    }
                    let otherMimeParams = parseMimeType(mimeTypeString: urlMimeType)
                    if selfMimeParams.type == otherMimeParams.type {
                        if typeMatch == nil {
                            typeMatch = url
                        }
                        if selfMimeParams.parameters["profile"] == otherMimeParams.parameters["profile"] {
                            typeAndProfileMatch = url
                            break
                        }
                    }
                }
            }
            let match = typeAndProfileMatch ?? (typeMatch ?? urls[0])
            guard let template = match.attributes["template"] else {
                completion(nil, OPDSParserOpenSearchHelperError.searchDocumentIsInvalid)
                return
            }

            completion(template, nil)
        }.resume()
    }

    static func parseMimeType(mimeTypeString: String) -> MimeTypeParameters {
        let substrings = mimeTypeString.split(separator: ";")
        let type = String(substrings[0]).trimmingCharacters(in: .whitespaces)
        var params = [String: String]()
        for defn in substrings.dropFirst() {
            let halves = defn.split(separator: "=")
            let paramName = String(halves[0]).trimmingCharacters(in: .whitespaces)
            let paramValue = String(halves[1]).trimmingCharacters(in: .whitespaces)
            params[paramName] = paramValue
        }
        return MimeTypeParameters(type: type, parameters: params)
    }

    static func parseEntry(entry: Fuzi.XMLElement, feedURL: URL) -> Publication? {
        // Shortcuts to get tag(s)' string value.
        func tag(_ name: String) -> String? {
            return entry.firstChild(tag: name)?.stringValue
        }
        func tags(_ name: String) -> [String] {
            return entry.children(tag: name).map { $0.stringValue }
        }

        guard let title = tag("title") else {
            return nil
        }

        let authors: [Contributor] = entry.children(tag: "author").compactMap { author in
            guard let name = author.firstChild(tag: "name")?.stringValue else {
                return nil
            }
            return Contributor(
                name: name,
                identifier: author.firstChild(tag: "uri")?.stringValue
            )
        }

        let subjects: [Subject] = entry.children(tag: "category").compactMap { category in
            guard let name = category.attributes["label"] else {
                return nil
            }
            return Subject(
                name: name,
                scheme: category.attributes["scheme"],
                code: category.attributes["term"]
            )
        }

        let metadata = Metadata(
            identifier: tag("identifier") ?? tag("id"),
            title: title,
            modified: tag("updated")?.dateFromISO8601,
            published: tag("published")?.dateFromISO8601,
            languages: tags("language"),
            subjects: subjects,
            authors: authors,
            publishers: tags("publisher").map { Contributor(name: $0) },
            description: tag("content") ?? tag("summary"),
            otherMetadata: [
                "rights": tags("rights").joined(separator: " "),
            ]
        )

        // Links.
        var images: [Link] = []
        var links: [Link] = []

        for linkElement in entry.children(tag: "link") {
            guard var href = linkElement.attributes["href"] else {
                continue
            }

            if href.contains("{pageNumber}") {
                href = href.replacingOccurrences(of: "{pageNumber}", with: "STT_PAGE_NUMBER_PLACEHOLDER")
            }

            guard let absoluteHref = URLHelper.getAbsolute(href: href, base: feedURL) else {
                continue
            }

            var properties: [String: Any] = [:]
            if let price = parsePrice(link: linkElement)?.json, !price.isEmpty {
                properties["price"] = price
            }
            let indirectAcquisition = parseIndirectAcquisition(children: linkElement.children(tag: "indirectAcquisition")).json
            if !indirectAcquisition.isEmpty {
                properties["indirectAcquisition"] = indirectAcquisition
            }

            properties["lastRead"] = linkElement.attributes["lastRead"]
            properties["count"] = linkElement.attributes["count"]

            let link = Link(
                href: absoluteHref,
                type: linkElement.attributes["type"],
                title: linkElement.attributes["title"],
                rel: linkElement.attributes["rel"].map { LinkRelation($0) },
                properties: .init(properties)
            )

            let rels = link.rels

            if rels.contains("collection") || rels.contains("http://opds-spec.org/group") {
                // no-op
            } else if rels.contains("http://opds-spec.org/image") || rels.contains("http://opds-spec.org/image-thumbnail") {
                images.append(link)
            } else {
                links.append(link)
            }
        }

        return Publication(
            manifest: Manifest(
                metadata: metadata,
                links: links,
                subcollections: [
                    "images": [PublicationCollection(links: images)],
                ]
            )
        )
    }

    static func addFacet(feed: Feed, to link: Link, named title: String) {
        for facet in feed.facets {
            if facet.metadata.title == title {
                facet.links.append(link)
                return
            }
        }
        let newFacet = Facet(title: title)

        newFacet.links.append(link)
        feed.facets.append(newFacet)
    }

    static func addPublicationInGroup(_ feed: Feed,
                                      _ publication: Publication,
                                      _ collectionLink: Link)
    {
        for group in feed.groups {
            for l in group.links {
                if l.href == collectionLink.href {
                    group.publications.append(publication)
                    return
                }
            }
        }
        if let title = collectionLink.title {
            let newGroup = Group(title: title)
            let selfLink = Link(
                href: collectionLink.href,
                title: collectionLink.title,
                rel: .self
            )
            newGroup.links.append(selfLink)
            newGroup.publications.append(publication)
            feed.groups.append(newGroup)
        }
    }

    static func addNavigationInGroup(_ feed: Feed,
                                     _ link: Link,
                                     _ collectionLink: Link)
    {
        for group in feed.groups {
            for l in group.links {
                if l.href == collectionLink.href {
                    group.navigation.append(link)
                    return
                }
            }
        }
        if let title = collectionLink.title {
            let newGroup = Group(title: title)
            let selfLink = Link(
                href: collectionLink.href,
                title: collectionLink.title,
                rel: .self
            )
            newGroup.links.append(selfLink)
            newGroup.navigation.append(link)
            feed.groups.append(newGroup)
        }
    }

    static func parseIndirectAcquisition(children: [Fuzi.XMLElement]) -> [OPDSAcquisition] {
        return children.compactMap { child in
            guard let type = child.attributes["type"] else {
                return nil
            }
            var acquisition = OPDSAcquisition(type: type)
            let grandChildren = child.children(tag: "indirectAcquisition")
            if grandChildren.count > 0 {
                acquisition.children = parseIndirectAcquisition(children: grandChildren)
            }
            return acquisition
        }
    }

    static func parsePrice(link: Fuzi.XMLElement) -> OPDSPrice? {
        guard let price = link.firstChild(tag: "price")?.stringValue,
              let value = Double(price),
              let currency = link.firstChild(tag: "price")?.attr("currencycode")
        else {
            return nil
        }

        return OPDSPrice(currency: currency, value: value)
    }
}

enum URLHelper {
    /**
     Check if an href destination is absolute or not.

     - parameter href: The destination.

     - returns: true only if href is absolute.
     */
    static func isAbsolute(href: String) -> Bool {
        if let url = URL(string: href) {
            if url.scheme != nil, url.host != nil {
                return true
            }
        }

        return false
    }

    /**
     Build an absolute href destination.

     - parameter href: The relative destination.
     - parameter base: The base URL.

     - returns: The absolute href destination.
     */
    static func getAbsolute(href: String?, base: URL?) -> String? {
        var absolute: String?

        if let href = href {
            if URLHelper.isAbsolute(href: href) {
                absolute = href
            } else {
                if let base = base {
                    absolute = URL(string: href, relativeTo: base)?.absoluteString
                }
            }
        }

        return absolute
    }
}

public extension Publication {
    var thumbnailURL: String? {
        links.first(withRel: .opdsImageThumbnail)?.href
    }

    var acquisitionLink: String? {
        links.first(withRel: .opdsAcquisition)?.href
    }

    var streamLink: R2Shared.Link? {
        links.first(withRel: .init("http://vaemendis.net/opds-pse/stream"))
    }

    var isStreamable: Bool {
        streamLink != nil
    }

    internal func toReadableChapter(clientID: String) throws -> ThreadSafeChapter {
        guard let link = streamLink, let id = metadata.identifier else {
            throw OPDSParserError.documentNotFound
        }

        return .init(id: "\(clientID)||\(id)",
                     sourceId: STTHelpers.OPDS_CONTENT_ID,
                     chapterId: link.href,
                     contentId: id,
                     index: 0,
                     number: 1,
                     volume: nil,
                     title: metadata.title,
                     language: "unknown",
                     date: .now,
                     webUrl: nil,
                     thumbnail: nil)
    }
}
