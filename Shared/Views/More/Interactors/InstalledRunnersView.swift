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
    @ObservedResults(StoredRunnerObject.self) var savedRunners
    @State var showAddSheet = false
    var body: some View {
        let sources = engine.getSources()
        List {
            Section {
                ForEach(sources) { source in
                    NavigationLink {
                        DaisukeContentSourceView(source: source)
                    } label: {
                        HStack(spacing: 15) {
                            STTThumbView(url: getSaved(source.id)?.thumb())
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
                }
                .onDelete { indexSet in
                    let sources = indexSet.compactMap(sources.get(index:))
                    sources.forEach { s in
                        try? engine.removeRunner(id: s.id)
                    }
                }
            } header: {
                Text("Content Sources")
            }
        }
        .navigationTitle("Installed Runners")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("\(Image(systemName: "plus"))") {
                    showAddSheet.toggle()
                }
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
                        try await DaisukeEngine.shared.importRunner(from:path)
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
}
