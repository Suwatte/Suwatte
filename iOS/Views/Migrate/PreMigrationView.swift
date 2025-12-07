//
//  PreMigrationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-03-07.
//

import RealmSwift
import SwiftUI

struct PreMigrationView: View {
    @StateObject private var model = PreMigrationController()
    private let manager = DSK.shared
    var body: some View {
        SmartNavigationView {
            ZStack {
                if model.loaded {
                    List {
                        InstalledSourcesSection
                        DanglingSourcesSection
                    }
                } else {
                    ProgressView()
                        .task {
                            await model.load()
                        }
                }
            }
            .animation(.default, value: model.loaded)
            .navigationTitle("Select Source")
            .closeButton()
            .onDisappear {
                model.shouldReset = true
            }
            .onAppear {
                if model.shouldReset {
                    model.loaded = false
                }
            }
            .toast()
        }
    }

    private func BuildSection(logs: [String: [TaggedHighlight]], title: String) -> some View {
        Section {
            ForEach(Array(logs.keys).sorted()) { key in
                let data = logs[key]!
                let source = model.sources.first(where: { $0.id == key })
                let name = source?.name ?? "Unknown"
                let version = source?.version

                NavigationLink {
                    MigrationView(model: .init(contents: data))
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom, spacing: 2) {
                                Text(name)
                                if let version {
                                    Text("v\(version.clean)")
                                        .font(.footnote)
                                        .fontWeight(.light)
                                        .foregroundStyle(.gray)
                                }
                            }
                            Text(key)
                                .font(.caption)
                                .fontWeight(.light)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text(data.count.description + " Title(s)")
                            .fontWeight(.light)
                            .opacity(0.50)
                    }
                }
            }
        } header: {
            Text(title)
        }
    }

    private var InstalledSourcesSection: some View {
        BuildSection(logs: model.data, title: "Installed Sources")
    }

    private var DanglingSourcesSection: some View {
        BuildSection(logs: model.dangling, title: "Unknown Sources")
    }
}

final class PreMigrationController: ObservableObject {
    @Published var data: [String: [TaggedHighlight]] = [:]
    @Published var dangling: [String: [TaggedHighlight]] = [:]
    @Published var sources: [AnyContentSource] = []
    @Published var loaded = false
    var shouldReset = false

    func load() async {
        let actor = await RealmActor.shared()
        let sources = await DSK
            .shared
            .getActiveSources()
            .filter { $0.ablityNotDisabled(\.disableMigrationDestination) }

        var prepped: [String: [TaggedHighlight]] = [:]

        for source in sources {
            let data = await actor
                .getLibraryEntries(for: source.id)
                .compactMap(\.content)
                .map { TaggedHighlight(from: $0.toHighlight(), with: $0.sourceId) }
            prepped[source.id] = data
        }

        // Get Dangling Entries
        let dangling = await actor.getDanglingLibraryHighlights(with: sources.map(\.id))

        await MainActor.run { [weak self, prepped] in
            self?.sources = sources
            self?.data = prepped
            self?.dangling = dangling
            self?.loaded = true
        }
    }
}
