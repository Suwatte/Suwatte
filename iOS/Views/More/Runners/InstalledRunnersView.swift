//
//  InstalledRunnersView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-07.
//

import RealmSwift
import SwiftUI

struct InstalledRunnersView: View {
    private let engine = DSK.shared
    @StateObject var model = ViewModel()
    @State var showAddSheet = false

    var groups: [RunnerEnvironment: [StoredRunnerObject]] {
        Dictionary(grouping: model.runners, by: \.safeEnvironment)
    }

    private var items: [RunnerEnvironment] {
        [.source, .tracker]
    }

    var body: some View {
        List {
            ForEach(items, id: \.hashValue) { environment in
                let runners = groups[environment] ?? []
                Section {
                    ForEach(runners) { runner in
                        Cell(runner)
                    }
                } header: {
                    Text(environment.description)
                }
            }
            .transition(.opacity)
        }
        .navigationTitle("Installed Runners")
        .task {
            await model.observe()
        }
        .onDisappear(perform: model.disconnect)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet.toggle() } label: {
                    Label("Add Runner", systemImage: "plus")
                }
            }
        }
        .animation(.default, value: model.runners)
        .fileImporter(isPresented: $showAddSheet, allowedContentTypes: [.init(filenameExtension: "stt")!]) { result in
            guard let path = try? result.get() else {
                ToastManager.shared.error("Task Failed")
                return
            }

            if path.startAccessingSecurityScopedResource() {
                Task {
                    do {
                        try await engine.importRunner(from: path)
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

    func Cell(_ runner: StoredRunnerObject) -> some View {
        NavigationLink {
            Gateway(runnerID: runner.id)
                .navigationTitle(runner.name)
        } label: {
            HStack(spacing: 15) {
                STTThumbView(url: URL(string: runner.thumbnail))
                    .frame(width: 44, height: 44, alignment: .center)
                    .cornerRadius(7)
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(runner.name)
                        .fontWeight(.semibold)
                    HStack(alignment: .lastTextBaseline) {
                        Text("v" + runner.version.description)
                            .font(.footnote.weight(.light))
                            .foregroundColor(.secondary)

                        if runner.isInstantiable {
                            Text("\(Image(systemName: "doc.on.doc"))")
                                .font(.footnote.weight(.light))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .disabled(!runner.enabled)
        .swipeActions {
            Button {
                Task {
                    await engine.removeRunner(runner.id)
                    StateManager.shared.browseUpdateRunnerPageLinks.send()
                    StateManager.shared.libraryUpdateRunnerPageLinks.send()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)

            if runner.isInstantiable && runner.enabled {
                Button {
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.createNewInstance(of: runner.id)
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
                .tint(.blue)
            }
        }
    }
}

extension InstalledRunnersView {
    final class ViewModel: ObservableObject {
        @Published var runners: [StoredRunnerObject] = []
        private var token: NotificationToken?

        func observe() async {
            token?.invalidate()
            token = nil

            let actor = await RealmActor.shared()

            token = await actor
                .observeInstalledRunners(onlyEnabled: false) { value in
                    Task { @MainActor in
                        self.runners = value
                    }
                }
        }

        func disconnect() {
            token?.invalidate()
            token = nil
        }
    }
}

extension InstalledRunnersView {
    struct Gateway: View {
        let runnerID: String
        var body: some View {
            LoadableRunnerView(runnerID: runnerID) { runner in
                if let source = runner as? AnyContentSource {
                    ContentSourceInfoView(source: source)
                } else if let tracker = runner as? JSCContentTracker {
                    ContentTrackerInfoView(tracker: tracker)
                }
            }
        }
    }
}
