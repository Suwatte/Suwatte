//
//  PreMigrationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-07.
//

import RealmSwift
import SwiftUI

struct PreMigrationView: View {
    @ObservedResults(LibraryEntry.self) var library
    private let manager = SourceManager.shared
    var body: some View {
        NavigationView {
            List {
                ForEach(sources, id: \.id) { source in
                    NavigationLink {
                        MigrationView(contents: library
                            .where { $0.content.sourceId == source.id }
                            .compactMap(\.content)
                        )
                    } label: {
                        Text(source.name)
                    }
                }
            }
            .navigationTitle("Select Source")
            .closeButton()
        }
    }

    var sources: [AnyContentSource] {
       []
    }
}

extension DataManager {
    func getUserLibrary(for id: String) -> [StoredContent] {
        let realm = try! Realm()

        let objects = realm
            .objects(LibraryEntry.self)
            .where { $0.content.sourceId == id }
            .compactMap(\.content)

        return Array(objects)
    }
}
