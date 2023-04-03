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
        @State var populated: [DSKCommon.PopulatedFilter]?
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
                    LoadedFiltersView(filters: value, populated: $populated, query: $query)
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
                            model.request.sort = model.sorters.first?.id
                            model.presentFilters.toggle()
                        }

                        Spacer()
                        if populated != model.request.filters {
                            Button("Apply") {
                                model.request.filters = populated
                                model.presentFilters.toggle()
                                Task.detached {
                                    await didSubmitSearch()
                                }
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

        func didSubmitSearch() {
            do {
                try DataManager.shared.saveSearch(model.request, sourceId: model.source.id, display: prepareSearch())

            } catch {
                Logger.shared.error("\(error)")
                ToastManager.shared.error(error)
            }
        }

        func prepareSearch() -> String {
            var texts: [String] = []
            guard let filters = filters.value else {
                return ""
            }

            for populated in model.request.filters ?? [] {
                // Get Filter
                let filter = filters.first(where: { $0.id == populated.id })
                guard let filter else {
                    continue
                }
                // Text
                if let value = populated.text {
                    texts.append("\(filter.title) : \(value)")
                }

                // Toggle
                if let value = populated.bool, value {
                    texts.append(filter.title)
                }

                // Included
                if let value = populated.included, !value.isEmpty, let selected = filter.options?.filter({ value.contains($0.id) }) {
                    let txt = "Including \(filter.title): \(selected.map(\.label).joined(separator: ", "))"
                    texts.append(txt)
                }

                // Excluded
                if let value = populated.excluded, !value.isEmpty, let selected = filter.options?.filter({ value.contains($0.id) }) {
                    let txt = "Excluding \(filter.title): \(selected.map(\.label).joined(separator: ", "))"
                    texts.append(txt)
                }
            }

            return texts.joined(separator: "\n")
        }
    }
}

extension ExploreView.SearchView.FilterSheet {
    struct LoadedFiltersView: View {
        @State var filters: [DaisukeEngine.Structs.Filter]
        @Binding var populated: [DSKCommon.PopulatedFilter]?
        @Binding var query: String

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(filters) {
                        SingleFilterView(filter: $0, savedFilters: $populated, query: $query)
                    }
                }
                .padding()
            }
        }
    }
}

extension ExploreView.SearchView.FilterSheet {
    struct SingleFilterView: View {
        var filter: DSKCommon.Filter
        @Binding var savedFilters: [DSKCommon.PopulatedFilter]?
        @Binding var query: String
        var body: some View {
            VStack(alignment: .leading) {
                Text(filter.title)
                    .font(.headline)
                    .fontWeight(.bold)
                if let subtitle = filter.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(.light)
                }

                Group {
                    switch filter.type {
                    case .info: EmptyView()
                    case .toggle: Toggle(filter.label ?? filter.title, isOn: ToggleBinding)
                    case .select, .multiselect, .excludableMultiselect:
                        InteractiveTagView(options) { tag in
                            Button {
                                withAnimation {
                                    handleOptionAction(tag)
                                }
                            } label: {
                                Text(tag.label)
                                    .modifier(ActionStyleModifier(color: optionColor(tag)))
                            }
                            .buttonStyle(.plain)
                        }
                    case .text:
                        HStack {
                            TextField(filter.label ?? filter.title, text: TextBinding)
                                .textFieldStyle(.roundedBorder)
                            Button("Clear", role: .destructive) {
                                setFilter()
                            }
                        }
                    }
                }
            }
        }

        // MARK: Binding

        var ToggleBinding: Binding<Bool> {
            .init {
                populated?.bool ?? false
            } set: { val in
                setFilter(bool: val)
            }
        }

        var TextBinding: Binding<String> {
            .init {
                populated?.text ?? ""
            } set: { val in
                setFilter(text: val.isEmpty ? nil : val)
            }
        }

        // MARK: Helper Functions

        var populated: DSKCommon.PopulatedFilter? {
            savedFilters?.first(where: { $0.id == filter.id })
        }

        var options: [DSKCommon.Option] {
            var ops = filter.options ?? []

            if !query.isEmpty {
                ops = ops.filter {
                    $0.label.lowercased().contains(query.lowercased())
                }
            }
            return ops.sorted(by: \.label, descending: false)
        }

        func setFilter(bool: Bool? = nil, text: String? = nil, included: [String]? = nil, excluded: [String]? = nil) {
            var idx = savedFilters?.firstIndex(where: { $0.id == filter.id })

            // Filter has not been populated
            if idx == nil {
                if savedFilters == nil { savedFilters = [] }
                savedFilters?.append(.init(id: filter.id))
                idx = savedFilters!.endIndex - 1
            }

            guard let idx else { return }
            savedFilters?[idx].bool = bool
            savedFilters?[idx].text = text
            savedFilters?[idx].included = included
            savedFilters?[idx].excluded = excluded
        }

        func handleOptionAction(_ option: DSKCommon.Option) {
            var included = Set(populated?.included ?? [])
            var excluded = Set(populated?.excluded ?? [])
            let id = option.id

            switch filter.type {
            case .select:
                if included.contains(id) {
                    included.remove(id)
                } else {
                    included.removeAll()
                    included.insert(id)
                }
            case .multiselect:
                if included.contains(id) {
                    included.remove(id)
                } else {
                    included.insert(id)
                }
            case .excludableMultiselect:
                if included.contains(id) {
                    included.remove(id)
                    excluded.insert(id)
                } else if excluded.contains(id) {
                    excluded.remove(id)
                } else {
                    included.insert(id)
                }

            default: break
            }

            setFilter(included: included.isEmpty ? nil : Array(included), excluded: excluded.isEmpty ? nil : Array(excluded))
        }

        func optionColor(_ option: DSKCommon.Option) -> Color {
            if populated?.included?.contains(option.id) ?? false { return .green }
            if populated?.excluded?.contains(option.id) ?? false { return .red }
            return .primary.opacity(0.1)
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
