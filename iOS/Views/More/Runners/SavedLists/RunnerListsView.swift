//
//  RunnerListsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import Alamofire
import FlagKit
import RealmSwift
import SwiftUI

struct RunnerListsView: View {
    @FetchRequest(fetchRequest: CDRunnerList.fetch(), animation: .default)
    private var records: FetchedResults<CDRunnerList>
    
    @AppStorage(STTKeys.AppAccentColor)
    private var color: Color = .sttDefault
    
    var body: some View {
        List {
            ForEach(records) {
                Cell(entry: $0)
            }
        }
        .navigationTitle("Saved Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("\(Image(systemName: "plus"))") {
                    promptURL()
                }
            }
        }
    }
}

// MARK: - Cell
extension RunnerListsView {
    private struct Cell: View {
        let entry : CDRunnerList
        
        var body : some View {
            NavigationLink {
                RunnerListInfo(listURL: entry.url)
                    .navigationTitle(entry.displayName)
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.displayName)
                        .font(.headline)
                    if entry.hasName {
                        Text(base)
                            .font(.subheadline)
                            .fontWeight(.light)
                            .opacity(0.65)
                    }
                }
            }
            .swipeActions(allowsFullSwipe: true) {
                Button {
                    CDRunnerList.delete(entry: entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        
        var base : String {
            entry.url
        }
    }
}

// MARK: - Methods
extension RunnerListsView {
    private func handleSubmit(url: String) async {
        if url.isEmpty { return }
        do {
            try await DSK.shared.saveRunnerList(at: url)
            ToastManager.shared.display(.info("Saved List!"))

        } catch {
            ToastManager.shared.error(error)
            Logger.shared.error(error)
        }
    }

    private func promptURL() {
        let ac = UIAlertController(title: "Enter List URL", message: "Suwatte will parse valid URLS.", preferredStyle: .alert)
        ac.addTextField()
        let field = ac.textFields![0]
        field.autocorrectionType = .no
        field.keyboardType = .URL
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [unowned ac] _ in
            let field = ac.textFields?.first
            guard let text = field?.text else {
                return
            }
            Task {
                await handleSubmit(url: text)
            }
        }
        ac.addAction(.init(title: "Cancel", style: .cancel, handler: { _ in }))
        ac.addAction(submitAction)
        getKeyWindow()?.rootViewController?.present(ac, animated: true)
    }
}

extension RunnerListsView {
    struct RunnerListInfo: View {
        let listURL: String
        @State private var loadable: Loadable<RunnerList> = .idle
        var body: some View {
            LoadableView(nil, load, $loadable) { value in
                RunnerListInfoView(list: value, url: listURL)
                    .task {
                        didLoad()
                    }
            }
            .animation(.default, value: loadable)
            .refreshable {
                loadable = .idle
            }
        }

        func load() async throws -> RunnerList {
            guard let url = URL(string: listURL) else {
                throw DaisukeEngine.Errors.NamedError(name: "Parse Error", message: "Invalid URL")
            }
            return try await DSK.shared.getRunnerList(at: url)
        }

        func didLoad() {
            guard let url = URL(string: listURL), let list = loadable.value else { return }
            Task {
                await CDRunnerList.add(entry: list, url: url)
            }
        }
    }
}


extension URL {
    var runnersListURL: URL {
        appendingPathComponent("runners.json")
    }
}
