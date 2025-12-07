//
//  WebtoonController+DataSource.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-20.
//

import Foundation
import OrderedCollections

private typealias Controller = WebtoonController

extension Controller {
    struct WCDataSource {
        var sections: OrderedSet<String> = []
        var dataMap: [String: [PanelViewerItem]] = [:]

        func itemIdentifier(for path: IndexPath) -> PanelViewerItem? {
            sections
                .getOrNil(path.section)
                .flatMap { dataMap[$0]?.getOrNil(path.item) }
        }

        mutating func appendSections(_ sections: [String]) {
            self.sections
                .append(contentsOf: sections)
        }

        mutating func appendItems(_ items: [PanelViewerItem], to section: String) {
            dataMap
                .updateValue(items, forKey: section)
        }

        func getSection(at idx: Int) -> String? {
            sections
                .getOrNil(idx)
        }

        var numberOfSections: Int {
            sections.count
        }

        func numberOfItems(in section: Int) -> Int {
            getSection(at: section)
                .flatMap { dataMap[$0]?.count } ?? 0
        }

        func itemIdentifiers(inSection section: String) -> [PanelViewerItem] {
            dataMap[section] ?? []
        }
    }
}
