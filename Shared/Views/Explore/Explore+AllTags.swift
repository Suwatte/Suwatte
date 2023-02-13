//
//  Explore+AllTagsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import SwiftUI

extension ExploreView {
    struct AllTagsView: View {
        @EnvironmentObject var source: DaisukeContentSource
        @State var properties: Loadable<[DaisukeEngine.Structs.Property]> = .idle
        @State var selectedTag: String?
        @State var text: String = ""

        var body: some View {
            LoadableView(loadData, properties) {
                DataLoadedView($0)
            }
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always))
            .transition(.opacity)
            .animation(.default, value: properties)
            .animation(.default, value: text)
            .navigationTitle("\(source.name) Tags")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension ExploreView.AllTagsView {
    func DataLoadedView(_ data: [DaisukeEngine.Structs.Property]) -> some View {
        List {
            ForEach(data) { property in
                let tags = tagsForProperty(property)
                if !tags.isEmpty {
                    Section {
                        ForEach(tags) {
                            Cell(for: $0, propertyId: property.id)
                        }
                    } header: {
                        Text(property.label)
                    }
                }
            }
        }
    }

    func tagsForProperty(_ property: DaisukeEngine.Structs.Property) -> [DaisukeEngine.Structs.Tag] {
        property.tags.sorted(by: { $0.label < $1.label }).filter { text.isEmpty ? true : $0.label.lowercased().contains(text.lowercased()) }
    }

    func Cell(for tag: DaisukeEngine.Structs.Tag, propertyId: String) -> some View {
        NavigationLink(tag.label) {
            let request = DaisukeEngine.Structs.SearchRequest(query: nil, page: 1,sort: nil, filters: [.init(id: propertyId, included: [tag.id] )])
            ExploreView.SearchView(model: .init(request: request, source: source), tagLabel: tag.label)
        }
    }
}

extension ExploreView.AllTagsView {
    func loadData() {
        properties = .loading
        Task {
            do {
                let data = try await source.getSourceTags()
                properties = .loaded(data)
            } catch {
                properties = .failed(error)
            }
        }
    }
}
