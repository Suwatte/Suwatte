//
//  ContentLanguageSettingsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-23.
//

import SwiftUI

struct ContentLanguageSettingsView: View {
    private let locales = Locale
        .isoLanguageCodes
        .compactMap { (Locale.current.localizedString(forIdentifier: $0) ?? $0, $0) }

    @State
    private var text: String = ""

    @Preference(\.globalContentLanguages)
    private var selections

    private var prepared: [(String, String)] {
        if text.isEmpty {
            return locales
                .sorted(by: \.0, descending: false)
        } else {
            return locales
                .filter { $0.0.lowercased()
                    .contains(text.lowercased()
                        .trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .sorted(by: \.0, descending: false)
        }
    }

    private var preparedSelections: [(String, String)] {
        selections
            .compactMap { (Locale.current.localizedString(forIdentifier: $0) ?? $0, $0) }
            .sorted(by: \.0, descending: false)
    }

    var body: some View {
        List {
            Section {
                if selections.isEmpty {
                    Text("All Languages")
                } else {
                    ForEach(preparedSelections, id: \.1) { name, id in
                        HStack {
                            Text(name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selections.remove(id)
                        }
                    }
                }
            } header: {
                Text("Selected")
            } footer: {
                if selections.isEmpty {
                    EmptyView()
                } else {
                    Text("Suwatte will only display chapters in the languages above.")
                }
            }

            Section {
                ForEach(prepared, id: \.1) { name, id in
                    HStack {
                        Text(name)
                        Spacer()
                        Image(systemName: "checkmark")
                            .transition(.opacity)
                            .opacity(selections.contains(id) ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selections.contains(id) {
                            selections.remove(id)
                        } else {
                            selections.insert(id)
                        }
                    }
                }
            } header: {
                Text("All")
            }
        }
        .searchable(text: $text,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search")
        .navigationTitle("Content Languages")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.default, value: text)
        .animation(.default, value: selections)
    }
}
