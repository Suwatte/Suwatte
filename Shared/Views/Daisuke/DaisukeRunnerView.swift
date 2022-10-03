//
//  DaisukeRunnerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-11.
//

import Kingfisher
import SwiftUI

struct DaisukeContentSourceView: View {
    @ObservedObject var source: DaisukeEngine.ContentSource
    @AppStorage(STTKeys.SourcesDisabledFromHistory) var sourcesDisabledFromHistory: [String] = []
    @AppStorage(STTKeys.SourcesHiddenFromGlobalSearch) var sourcesHiddenFromGlobalSearch: [String] = []
    var body: some View {
        List {
            HeaderSection
            InfoSection
            if let info = (source.info as? DSK.ContentSource.ContentSourceInfo), let authMethod = info.authMethod {
                AuthSection(authMethod: authMethod, canSync: info.canSync)
            }

            Section {
                NavigationLink("Preferences") {
                    PreferencesView()
                        .environmentObject(source)
                        .navigationTitle("Preferences")
                }
                NavigationLink("Actions") {
                    ActionsView()
                        .environmentObject(source)
                }
            } header: {
                Text("Settings")
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
        .environmentObject(source)
    }

    @ViewBuilder
    func SourceInfo(source: DSK.ContentSource) -> some View {
        let info = source.info

        Section {}
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
            Text("Supported Language")
                .badge(Text(flag))

            Link(destination: URL(string: source.sourceInfo.website) ?? STTHost.notFound) {
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
        let count = source.sourceInfo.supportedLanguages.count
        if count == 0 || count > 1 {
            return .getFlag(from: "multi")
        } else if let s = source.sourceInfo.supportedLanguages.first {
            return .getFlag(from: s)
        }
        return .getFlag(from: "unknown")
    }
}
