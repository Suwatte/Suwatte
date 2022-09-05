//
//  AnilistView+DirectoryView+FilterSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import SwiftUI

extension AnilistView.DirectoryView {
    struct FilterSheet: View {
        @EnvironmentObject var model: ViewModel
        @Environment(\.presentationMode) var presentationMode

        func loadGenres() {
            Task {
                await model.getGenres()
            }
        }

        var body: some View {
            NavigationView {
                List {
                    // Adult Content
                    Section {
                        NavigationLink("Adult Content") {
                            AdultContentView(value: $model.request.isAdult)
                        }
                    } header: {
                        Text("Content Preferences")
                    }

                    // Genres & Tags
                    Section {
                        LoadableView(loadGenres, model.genres) { options in
                            NavigationLink {
                                GenreView(include: $model.request.genres, exclude: $model.request.excludedGenres, data: options.genres)
                            } label: {
                                STTLabelView(title: "Genres", label: model.request.GenreLabel)
                            }
                            NavigationLink {
                                TagView(include: bindedTags, exlude: bindedExcludedTags, data: options.tags.filter { model.request.isAdult ?? true ? true : !$0.isAdult })
                            } label: {
                                STTLabelView(title: "Tags", label: model.request.TagLabel)
                            }
                        }
                    } header: {
                        Text("Genres & Tags")
                    }
                }
                .headerProminence(.increased)
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Apply") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        Spacer()
                        Button("Reset") {
                            presentationMode.wrappedValue.dismiss()
                            model.reset()
                        }
                    }
                }
                .closeButton()
            }
            // Genres

            // Year
            // Season
            // Format
            // Country of Origin
            // Source Material
            // Year Range

            // ANIME Specific
            // Airing Status
            // Streaming On
            // Episodes
            // Duration

            // MANGA Specific
            // Readable On
            // Chapters
            // Volume
            // Publishing Status

            // Doujin
            // Hide my Anime
            // Only show my anime
            // Adult

            // Advanced Genres & Tag Filters

            // Mininum Tag Percentage

            // Genre List
        }
    }
}

private typealias FilterSheet = AnilistView.DirectoryView.FilterSheet

// MARK: Genre View

extension FilterSheet {
    struct GenreView: View {
        @Binding var include: [String]?
        @Binding var exclude: [String]?
        var data: [String]
        var body: some View {
            List {
                ForEach(data) { option in
                    Button { toggleSelection(option) } label: {
                        HStack {
                            Text(option)
                            Spacer()
                            Circle()
                                .frame(width: 8, height: 8, alignment: .center)
                                .foregroundColor(cellColor(option))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(.default, value: include)
            .animation(.default, value: exclude)
            .navigationTitle("Genres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        reset()
                    }
                }
            }
        }

        func cellColor(_ selection: String) -> Color {
            include?.contains(selection) ?? false ?
                .green : exclude?.contains(selection) ?? false ?
                .red : .clear
        }

        func toggleSelection(_ selection: String) {
            if exclude?.contains(selection) ?? false {
                exclude?.removeAll(where: { $0 == selection })
            } else if include?.contains(selection) ?? false {
                include?.removeAll(where: { $0 == selection })

                if exclude?.isEmpty ?? true {
                    exclude = [selection]
                } else {
                    exclude?.append(selection)
                }

            } else {
                if include?.isEmpty ?? true {
                    include = [selection]
                } else {
                    include?.append(selection)
                }
            }

            if include != nil, include!.isEmpty {
                include = nil
            }
            if exclude != nil, exclude!.isEmpty {
                exclude = nil
            }

//            print(include, exclude, "\n")
        }

        func reset() {
            include = nil
            exclude = nil
        }
    }
}

// MARK: Tag View

extension FilterSheet {
    var bindedTags: Binding<[String]> {
        .init(get: { model.request.tags ?? [] }, set: {
            if $0.isEmpty {
                model.request.tags = nil
            } else {
                model.request.tags = $0
            }
        })
    }

    var bindedExcludedTags: Binding<[String]> {
        .init(get: { model.request.excludedTags ?? [] }, set: {
            if $0.isEmpty {
                model.request.excludedTags = nil
            } else {
                model.request.excludedTags = $0
            }
        })
    }

    struct TagView: View {
        @Binding var include: [String]
        @Binding var exlude: [String]
        @State var text: String = ""
        var data: [Anilist.Tag]
        var body: some View {
            let grouped = groupedData
            List {
                ForEach(Array(grouped.keys).sorted(by: { $0 < $1 })) { key in
                    CategorySection(key, grouped[key]!)
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always))
            .animation(.default, value: include)
            .animation(.default, value: exlude)
            .animation(.default, value: text)
        }

        var groupedData: [String: [Anilist.Tag]] {
            Dictionary(grouping: data.filter { text.isEmpty ? true : $0.name.lowercased().contains(text.lowercased()) }, by: { $0.category })
        }

        func CategorySection(_ key: String, _ data: [Anilist.Tag]) -> some View {
            Section {
                ForEach(data, id: \.name) {
                    Cell($0)
                }
            } header: {
                Text(key)
            }
            .headerProminence(.increased)
        }

        func Cell(_ tag: Anilist.Tag) -> some View {
            Button { toggleSelection(tag.name) } label: {
                HStack {
                    if tag.isAdult {
                        Image(systemName: "18.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20, alignment: .center)
                            .foregroundColor(.red)
                    }
                    Text(tag.name)
                    Spacer()
                    Circle()
                        .frame(width: 8, height: 8, alignment: .center)
                        .foregroundColor(cellColor(tag.name))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        func reset() {
            include.removeAll()
            exlude.removeAll()
        }

        func cellColor(_ selection: String) -> Color {
            include.contains(selection) ?
                .green : exlude.contains(selection) ?
                .red : .clear
        }

        func toggleSelection(_ selection: String) {
            STTHelpers.toggleSelection(list1: &include, list2: &exlude, element: selection)
        }
    }
}

extension FilterSheet {
    struct AdultContentView: View {
        @Binding var value: Bool?
        var body: some View {
            List {
                Button { value = false } label: {
                    Cell("Hide Adult Content", isSelected: value == false)
                }
                Button { value = nil } label: {
                    Cell("Include Adult Content", isSelected: value == nil)
                }
                Button { value = true } label: {
                    Cell("Show only Adult Content", isSelected: value == true)
                }
            }
            .buttonStyle(.plain)
            .navigationTitle("Adult Content")
            .navigationBarTitleDisplayMode(.inline)
        }

        func Cell(_ label: String, isSelected: Bool) -> some View {
            HStack {
                Text(label)
                Spacer()
                Image(systemName: "checkmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15, alignment: .center)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
    }
}

extension Anilist.SearchRequest {
    var GenreLabel: String {
        let includedCount = genres?.count ?? 0
        let excludedCount = excludedGenres?.count ?? 0

        var str = ""
        if includedCount >= 1 { str += "\(includedCount) Included" }
        if excludedCount >= 1, includedCount >= 1 { str += ", " }
        if excludedCount >= 1 { str += "\(excludedCount) Excluded" }
        return str
    }

    var TagLabel: String {
        let includedCount = tags?.count ?? 0
        let excludedCount = excludedTags?.count ?? 0

        var str = ""
        if includedCount >= 1 { str += "\(includedCount) Included" }
        if excludedCount >= 1, includedCount >= 1 { str += ", " }
        if excludedCount >= 1 { str += "\(excludedCount) Excluded" }

        return str
    }
}
