//
//  ContentSourceView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import SwiftUI

struct ContentSourceInfoView: View {
    var source: AnyContentSource
    @AppStorage(STTKeys.SourcesDisabledFromHistory) var sourcesDisabledFromHistory: [String] = []
    @AppStorage(STTKeys.SourcesHiddenFromGlobalSearch) var sourcesHiddenFromGlobalSearch: [String] = []

    var body: some View {
        List {
            HeaderSection
            InfoSection

            if source.intents.authenticatable, source.intents.authenticationMethod != .unknown {
                DSKAuthView(model: .init(runner: source))
            }

            if source.intents.preferenceMenuBuilder {
                Section {
                    NavigationLink("Preferences") {
                        DSKPreferenceView(runner: source)
                            .navigationTitle("Preferences")
                    }
                } header: {
                    Text("Settings")
                }
            }

            Section {
                Toggle("Disable Progress Marking", isOn: .init(get: {
                    sourcesDisabledFromHistory.contains(source.id)
                }, set: { value in
                    if value {
                        sourcesDisabledFromHistory.append(source.id)
                        sourcesDisabledFromHistory = Array(Set(sourcesDisabledFromHistory))
                    } else {
                        sourcesDisabledFromHistory.removeAll(where: { $0 == source.id })
                    }
                }))
                Toggle("Hide From Global Search", isOn: .init(get: {
                    sourcesHiddenFromGlobalSearch.contains(source.id)
                }, set: { value in
                    if value {
                        sourcesHiddenFromGlobalSearch.append(source.id)
                        sourcesHiddenFromGlobalSearch = Array(Set(sourcesHiddenFromGlobalSearch))
                    } else {
                        sourcesHiddenFromGlobalSearch.removeAll(where: { $0 == source.id })
                    }
                }))
            } header: {
                Text("Global Source Settings")
            }
        }
        .navigationTitle(source.name)
    }

    var HeaderSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(source.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(source.version.description)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.5))
                }
            }
        }
    }

    var InfoSection: some View {
        Section {
            if let languages = source.info.supportedLanguages {
                if languages.count > 1 {
                    NavigationLink {
                        List {
                            ForEach(languages.sorted(by: { Locale.current.localizedString(forIdentifier: $0) ?? "" < Locale.current.localizedString(forIdentifier: $1) ?? "" })) {
                                LanguageCellView(language: $0)
                            }
                        }
                        .navigationTitle("Supported Languages")
                    } label: {
                        Text("Supported Languages")
                    }
                } else {
                    HStack {
                        Text("Supported Language")
                        Spacer()
                        LanguageCellView(language: languages.first ?? "Unknown")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Link(destination: URL(string: source.info.website) ?? STTHost.notFound) {
                HStack {
                    Text("Visit Website")
                    Spacer()
                    Image(systemName: "globe")
                }
            }
            .buttonStyle(.plain)
        }
    }

    var flag: String {
        ""
    }
}
