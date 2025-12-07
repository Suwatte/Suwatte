//
//  DV+FilterView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import AnyCodable
import SwiftUI

extension DirectoryView {
    struct FilterView: View {
        var filters: [DSKCommon.DirectoryFilter]
        @State private var query = ""
        @State private var data: [String: AnyCodable] = [:]
        @EnvironmentObject private var model: ViewModel
        var body: some View {
            SmartNavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(filters, id: \.id) {
                            Cell(filter: $0, query: $query, data: $data)
                        }
                    }
                    .padding()
                }
                .animation(.default, value: query)
                .navigationBarTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
                .task {
                    data = model.request.filters ?? [:]
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button("Close") {
                            model.presentFilters.toggle()
                        }
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Reset") {
                            model.reset()
                            model.reloadRequest()
                            model.presentFilters.toggle()
                        }

                        Spacer()
                        Button("Apply") {
                            model.reset()
                            model.request.filters = data
                            model.reloadRequest()
                            model.presentFilters.toggle()

                            Task {
                                await saveSearch()
                            }
                        }
                        .disabled(data == (model.request.filters ?? [:]))
                    }
                }
            }
        }

        func saveSearch() async {
            let title = prepareSearch().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            let actor = await RealmActor.shared()
            await actor.saveSearch(model.request, sourceId: model.runner.id, display: title)
        }

        func prepareSearch() -> String {
            var texts: [String] = []

            for filter in filters {
                // Get Filter
                let target = data[filter.id]
                guard let target else {
                    continue
                }

                let label = filter.label ?? filter.title
                let options = filter.options ?? []
                switch filter.type {
                case .text:
                    if let str = (target.value as? String) {
                        texts.append("\(label): \(str)")
                    }
                case .toggle:
                    if target.value is Bool {
                        texts.append(label)
                    }
                case .select:
                    if let val = target.value as? String, let option = options.first(where: { $0.id == val }) {
                        texts.append("Including \(label): \(option.title)")
                    }
                case .multiselect:
                    if let val = target.value as? [String] {
                        let selected = options.filter { val.contains($0.id) }
                        if selected.isEmpty { continue }
                        texts.append("Including \(label): \(selected.map(\.title).joined(separator: ", "))")
                    } else if let val = target.value as? Set<String> {
                        let selected = options.filter { val.contains($0.id) }
                        if selected.isEmpty { continue }
                        texts.append("Including \(label): \(selected.map(\.title).joined(separator: ", "))")
                    }
                case .excludableMultiselect:
                    var val: DSKCommon.ExcludableMultiSelectProp? = nil
                    if let value = target.value as? DSKCommon.ExcludableMultiSelectProp {
                        val = value
                    } else if let dict = target.value as? [String: Any], let value = try? DSKCommon.ExcludableMultiSelectProp(dict: dict) {
                        val = value
                    }

                    guard let val else { continue }
                    let included = options.filter { val.included.contains($0.id) }.map(\.title).joined(separator: ", ")
                    let excluded = options.filter { val.excluded.contains($0.id) }.map(\.title).joined(separator: ", ")
                    if !included.isEmpty {
                        let txt = "Including \(label): \(included)"
                        texts.append(txt)
                    }

                    if !excluded.isEmpty {
                        let txt = "Excluding \(label): \(excluded)"
                        texts.append(txt)
                    }
                default: break
                }
            }
            return texts.joined(separator: "\n")
        }
    }
}

// MARK: FilterView Cell

extension DirectoryView.FilterView {
    struct Cell: View {
        var filter: DSKCommon.DirectoryFilter
        @Binding var query: String
        @Binding var data: [String: AnyCodable]
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

                ZStack {
                    switch filter.type {
                    case .info: EmptyView()
                    case .toggle: ToggleView(filter: filter, data: $data)
                    case .select, .multiselect, .excludableMultiselect: SelectView(filter: filter, query: query, data: $data)
                    case .text: TextView(filter: filter, data: $data)
                    }
                }
            }
        }
    }
}

// MARK: ToggleView

extension DirectoryView.FilterView.Cell {
    struct ToggleView: View {
        var filter: DSKCommon.DirectoryFilter
        @Binding var data: [String: AnyCodable]

        var body: some View {
            Toggle(filter.label ?? filter.title, isOn: binding)
        }

        var binding: Binding<Bool> {
            .init {
                (data[filter.id]?.value as? Bool) ?? false
            } set: {
                data[filter.id] = AnyCodable($0)
            }
        }
    }
}

// MARK: Select View

extension DirectoryView.FilterView.Cell {
    struct SelectView: View {
        var filter: DSKCommon.DirectoryFilter
        var query: String
        @Binding var data: [String: AnyCodable]
        @State var props = DSKCommon.ExcludableMultiSelectProp(included: [], excluded: [])

        var options: [DSKCommon.Option] {
            var ops = filter.options ?? []

            if !query.isEmpty {
                ops = ops.filter {
                    $0.title.lowercased().contains(query.lowercased())
                }
            }

            return ops
        }

        var body: some View {
            InteractiveTagView(options) { tag in
                Button {
                    withAnimation {
                        handle(tag)
                    }
                } label: {
                    Text(tag.title)
                        .modifier(ActionStyleModifier(color: optionColor(tag)))
                }
                .buttonStyle(.plain)
            }
            .task {
                guard let value = data[filter.id]?.value else { return }
                if let val = value as? String {
                    props.included.insert(val)
                    return
                }

                if let val = value as? [String] {
                    val.forEach { props.included.insert($0) }
                    return
                }

                if let val = value as? Set<String> {
                    props.included = val
                    return
                }

                if let val = value as? DSKCommon.ExcludableMultiSelectProp {
                    props = val
                } else if let dict = value as? [String: Any], let val = try? DSKCommon.ExcludableMultiSelectProp(dict: dict) {
                    props = val
                }
            }
        }

        // MARK: Methods

        func optionColor(_ option: DSKCommon.Option) -> Color {
            if props.included.contains(option.id) { return .green }
            if props.excluded.contains(option.id) { return .red }
            return .primary.opacity(0.1)
        }

        func handle(_ option: DSKCommon.Option) {
            let id = option.id
            switch filter.type {
            case .select:
                if props.included.contains(id) {
                    props.included.remove(id)
                } else {
                    props.included.removeAll()
                    props.included.insert(id)
                }
            case .multiselect:
                if props.included.contains(id) {
                    props.included.remove(id)
                } else {
                    props.included.insert(id)
                }
            case .excludableMultiselect:
                if props.included.contains(id) {
                    props.included.remove(id)
                    props.excluded.insert(id)
                } else if props.excluded.contains(id) {
                    props.excluded.remove(id)
                } else {
                    props.included.insert(id)
                }
            default: break
            }

            switch filter.type {
            case .select:
                if props.included.isEmpty {
                    data.removeValue(forKey: filter.id)
                } else {
                    data.updateValue(AnyCodable(props.included.first!), forKey: filter.id)
                }
            case .multiselect:
                if props.included.isEmpty {
                    data.removeValue(forKey: filter.id)
                } else {
                    data.updateValue(AnyCodable(props.included), forKey: filter.id)
                }
            case .excludableMultiselect:
                if props.included.isEmpty, props.excluded.isEmpty {
                    data.removeValue(forKey: filter.id)
                } else {
                    data.updateValue(AnyCodable(props), forKey: filter.id)
                }
            default: break
            }
        }
    }
}

extension DirectoryView.FilterView.Cell.SelectView {
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

// MARK: TextView

extension DirectoryView.FilterView.Cell {
    struct TextView: View {
        var filter: DSKCommon.DirectoryFilter
        @Binding var data: [String: AnyCodable]
        var body: some View {
            HStack {
                TextField(filter.label ?? filter.title, text: binding)
                    .textFieldStyle(.roundedBorder)
                Button("Clear", role: .destructive) {
                    data.removeValue(forKey: filter.id)
                }
            }
        }

        var binding: Binding<String> {
            .init {
                data[filter.id]?.value as? String ?? ""
            } set: { val in
                if val.isEmpty {
                    data.removeValue(forKey: filter.id)
                } else {
                    data.updateValue(AnyCodable(val), forKey: filter.id)
                }
            }
        }
    }
}
