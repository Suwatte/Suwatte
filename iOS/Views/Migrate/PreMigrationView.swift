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
            Group {
                if model.loaded {
                    List {
                        ForEach(model.sources, id: \.id) { source in
                            let data = model.data[source.id]
                            if let data {
                                NavigationLink {
                                    MigrationView(model: .init(contents: data))
                                } label: {
                                    HStack {
                                        Text(source.name)
                                        Spacer()
                                        Text(data.count.description + " Title(s)")
                                            .fontWeight(.light)
                                            .opacity(0.50)
                                    }
                                }
                            } else {
                                EmptyView()
                            }
                        }
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
}

final class PreMigrationController: ObservableObject {
    @Published var data: [String: [TaggedHighlight]] = [:]
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
        let final = prepped
        await MainActor.run { [weak self] in
            self?.sources = sources
            self?.data = final
            self?.loaded = true
        }
    }
}
