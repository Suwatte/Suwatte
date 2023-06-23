//
//  PreMigrationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-07.
//

import RealmSwift
import SwiftUI

struct PreMigrationView: View {
    @ObservedResults(StoredRunnerObject.self, where: { $0.isDeleted == false && $0.enabled == true }, sortDescriptor: SortDescriptor(keyPath: "name", ascending: true)) private var sources
    @ObservedResults(LibraryEntry.self, where: { $0.isDeleted == false && $0.content != nil }, sortDescriptor: .init(keyPath: "content.title", ascending: false)) private var library
    private let manager = SourceManager.shared
    var body: some View {
        NavigationView {
            List {
                ForEach(sources, id: \.id) { source in
                    var scopedLibrary = library.where { $0.content.sourceId == source.id }
                    NavigationLink {
                        MigrationView(contents: scopedLibrary.compactMap(\.content))
                    } label: {
                        HStack {
                            STTThumbView(url: URL(string: source.thumbnail))
                                .frame(width: 32.0, height: 32.0)
                                .cornerRadius(5)
                            Text(source.name)
                            Spacer()
                            Text(scopedLibrary.count.description + " Title(s)")
                                .fontWeight(.light)
                                .opacity(0.50)
                        }
                    }
                }
            }
            .navigationTitle("Select Source")
            .closeButton()
        }
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
