//
//  ESV+FiltersSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-05.
//

import SwiftUI

extension ExploreView.SearchView {
    struct FilterSheet: View {
        @EnvironmentObject var model: ExploreView.SearchView.ViewModel
        typealias Filter = DaisukeEngine.Structs.Filter
        @State var filters: Loadable<[Filter]> = .idle
        @State var query = ""
        var body: some View {
            NavigationView {
                LoadableView(loadable: filters, {
                    ProgressView().task {
                        await loadFilters()
                    }
                }, {
                    ProgressView()
                }, { error in
                    ErrorView(error: error) {
                        Task {
                            await loadFilters()
                        }
                    }
                }, { value in
                    LoadedFiltersView(filters: value, request: $model.request, query: $query)
                })
                .animation(.default, value: query)
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button("Close") {
                            model.presentFilters.toggle()
                        }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") {
                            model.request = .init(page: 1)
                            model.request.sort = model.sorters.first
                            model.presentFilters.toggle()
                        }

                        Spacer()
                        if let filters = filters.value {
                            Button("Apply") {
                                DataManager.shared.saveSearch(model.request.includedTags, model.request.excludedTags, model.source.id, filters)
                                model.presentFilters.toggle()
                            }
                        }
                    }
                }
            }
        }

        func loadFilters() async {
            do {
                let response = try await model.source.getSearchFilters()
                filters = .loaded(response)
            } catch {
                filters = .failed(error)
            }
        }
    }
}

extension ExploreView.SearchView.FilterSheet {
    struct LoadedFiltersView: View {
        @State var filters: [DaisukeEngine.Structs.Filter]
        @Binding var request: DaisukeEngine.Structs.SearchRequest
        @Binding var query: String

        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(filters) { filter in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(filter.property.label)
                                .font(.headline)
                                .fontWeight(.bold)

                            InteractiveTagView(filteredTags(tags: filter.property.tags)) { tag in
                                Button {
                                    withAnimation {
                                        handleAction(for: tag, canExclude: filter.canExclude)
                                    }

                                } label: {
                                    Text(tag.label)
                                        .modifier(ActionStyleModifier(color: backgroundColor(tag: tag)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
        }

        func filteredTags(tags: [DSKCommon.Tag]) -> [DSKCommon.Tag] {
            var tags = tags

            if !query.isEmpty {
                tags = tags.filter {
                    $0.label.lowercased().contains(query.lowercased())
                }
            }
            return tags.sorted(by: \.label, descending: false)
        }

        typealias Tag = DaisukeEngine.Structs.Tag
        func backgroundColor(tag: Tag) -> Color {
            includes(tag) ? .green : excludes(tag) ? .red : .primary.opacity(0.1)
        }

        func includes(_ tag: Tag) -> Bool {
            request.includedTags.contains(where: { $0 == tag.id })
        }

        func excludes(_ tag: Tag) -> Bool {
            request.excludedTags.contains(where: { $0 == tag.id })
        }

        func handleAction(for tag: Tag, canExclude: Bool) {
            if includes(tag) {
                request.includedTags.removeAll(where: { $0 == tag.id })

                if canExclude {
                    request.excludedTags.append(tag.id)
                }
            } else if excludes(tag) {
                request.excludedTags.removeAll(where: { $0 == tag.id })
            } else {
                request.includedTags.append(tag.id)
            }
        }
    }
}

extension ExploreView.SearchView.FilterSheet {
    struct ActionStyleModifier: ViewModifier {
        var color: Color
        func body(content: Content) -> some View {
            content
                .font(.callout.weight(.light))
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(color)
                .foregroundColor(Color.primary)
                .cornerRadius(3)
        }
    }
}
