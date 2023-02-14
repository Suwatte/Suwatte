//
//  InstalledRunnersView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import RealmSwift
import SwiftUI

struct InstalledRunnersView: View {
    @ObservedObject var engine = DaisukeEngine.shared
    @ObservedResults(StoredRunnerObject.self, sortDescriptor: .init(keyPath: "name", ascending: true)) var savedRunners
    @State var showAddSheet = false
    @Environment(\.editMode) var editMode
    var body: some View {
        let sources = engine.getSources().sorted(by: { getSaved($0.id)?.order ?? 0 < getSaved($1.id)?.order ?? 0 })
        List {
            Section {
                ForEach(sources, id: \.id) { source in
                    NavigationLink {
                        if let source = source as? DSK.LocalContentSource {
                            DaisukeContentSourceView(source: source)
                        } else {
                            Text("Hosted Source Menu")
                        }
                    } label: {
                        HStack(spacing: 15) {
                            STTThumbView(url: getSaved(source.id)?.thumbnail.flatMap { URL(string: $0) })
                                .frame(width: 44, height: 44, alignment: .center)
                                .cornerRadius(7)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(source.name)
                                    .fontWeight(.semibold)
                                Text("v" + source.version.clean)
                                    .font(.footnote.weight(.light))
                            }
                        }
                    }
                    .disabled(editMode?.wrappedValue == .active)
                    .disabled(source is DSK.HostedContentSource)
                }
                .onDelete { indexSet in
                    let sources = indexSet.compactMap(sources.get(index:))
                    sources.forEach { s in
                        try? engine.removeRunner(id: s.id)
                    }
                }
//                .onMove(perform: move)
            } header: {
                Text("Content Sources")
            }
        }
        .navigationTitle("Installed Runners")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button { showAddSheet.toggle() } label: {
                    Label("Add Runner", systemImage: "plus")
                }
                EditButton()
            }
        }
        .fileImporter(isPresented: $showAddSheet, allowedContentTypes: [.init(filenameExtension: "stt")!]) { result in

            guard let path = try? result.get() else {
                ToastManager.shared.error("Task Failed")
                return
            }

            if path.startAccessingSecurityScopedResource() {
                Task {
                    do {
                        try await DaisukeEngine.shared.importRunner(from: path)
                        await MainActor.run {
                            ToastManager.shared.info("Added!")
                        }
                    } catch {
                        await MainActor.run {
                            ToastManager.shared.error(error)
                        }
                    }
                    path.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    func getSaved(_ id: String) -> StoredRunnerObject? {
        savedRunners
            .where { $0.id == id }
            .first
    }

    func move(from source: IndexSet, to destination: Int) {
        var arr = Array(savedRunners)
        arr.move(fromOffsets: source, toOffset: destination)
        DataManager.shared.reorderRunners(arr)
    }
}

private extension DataManager {
    func reorderRunners(_ arr: [StoredRunnerObject]) {
        let realm = try! Realm()

        try! realm.safeWrite {
            for runner in arr {
                if let target = realm.objects(StoredRunnerObject.self).first(where: { $0.id == runner.id }) {
                    target.order = arr.firstIndex(of: runner)!
                }
            }
        }
    }
}
