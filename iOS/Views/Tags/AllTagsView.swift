//
//  AllTagsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct AllTagsView: View {
    var source: AnyContentSource
    @State var properties: Loadable<[DaisukeEngine.Structs.Property]> = .idle
    @State var selectedTag: String?
    @State var text: String = ""
    var body: some View {
        LoadableView(loadData, $properties) {
            DataLoadedView($0)
        }
        .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always))
        .transition(.opacity)
        .animation(.default, value: properties)
        .animation(.default, value: text)
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AllTagsView {
    func DataLoadedView(_ data: [DSKCommon.Property]) -> some View {
        List {
            ForEach(data) { property in
                let tags = tagsForProperty(property)
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) {
                            Cell(for: $0, propertyId: property.id)
                        }
                    } header: {
                        Text(property.title)
                    }
                }
            }
        }
    }

    func tagsForProperty(_ property: DaisukeEngine.Structs.Property) -> [DSKCommon.Tag] {
        property.tags.sorted(by: { $0.title < $1.title }).filter { text.isEmpty ? true : $0.title.lowercased().contains(text.lowercased()) }
    }

    func Cell(for tag: DaisukeEngine.Structs.Tag, propertyId: String) -> some View {
        NavigationLink(tag.title) {
            let request = DSKCommon.DirectoryRequest(page: 1, tag: .init(tagId: tag.id, propertyId: propertyId))
            ContentSourceDirectoryView(source: source, request: request)
                .navigationBarTitle("\(tag.title)")
        }
    }
}

extension AllTagsView {
    func loadData() {
        properties = .loading
        Task {
            do {
                let data = try await source.getAllTags()
                properties = .loaded(data)
            } catch {
                properties = .failed(error)
            }
        }
    }
}
