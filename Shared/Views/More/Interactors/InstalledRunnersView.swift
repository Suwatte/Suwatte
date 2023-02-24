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
    @ObservedResults(StoredRunnerObject.self) var runners
    @State var showAddSheet = false
    var body: some View {
        let results = runners.sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true), SortDescriptor(keyPath: "name", ascending: true)])
        List {
            Section {
                ForEach(results, id: \.id) { runner in
                    if let source = DSK.shared.getSource(with: runner.id) {
                        NavigationLink {
                            if let source = source as? DSK.LocalContentSource {
                                DaisukeContentSourceView(source: source)
                            } else {
                                Text("Hosted Source Menu")
                            }
                        } label: {
                            HStack(spacing: 15) {
                                STTThumbView(url:  URL(string: runner.thumbnail) )
                                    .frame(width: 44, height: 44, alignment: .center)
                                    .cornerRadius(7)
                                VStack(alignment: .leading, spacing: 2.5) {
                                    Text(source.name)
                                        .fontWeight(.semibold)
                                    Text(source.version.clean)
                                        .font(.footnote.weight(.light))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .swipeActions(allowsFullSwipe: true) {
                            Button {
                                try? engine.removeRunner(id: runner.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                        }
                    }
                }
            } header: {
                Text("Content Sources")
            }
            .opacity(results.isEmpty ? 0 : 1)
        }
        .navigationTitle("Installed Runners")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet.toggle() } label: {
                    Label("Add Runner", systemImage: "plus")
                }
            }
        }
        .animation(.default,value: engine.sources)
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
}

