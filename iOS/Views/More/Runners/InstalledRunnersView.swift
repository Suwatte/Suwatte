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
    var body: some View {
        List {
            if let r = model.runners  {
                let grouped = Dictionary(grouping: r, by: \.environment)
                let keys = grouped.filter({ !$0.value.isEmpty }).keys.sorted(by: \.description)
                ForEach(Array(keys), id: \.description) { key in
                    let runners = grouped[key] ?? []
                    
                    Section {
                        ForEach(runners, id: \.id) { runner in
                            
                            let dskRunner = engine.getRunner(runner.id)
                            let isActive = dskRunner != nil
                            NavigationLink {
                                
                                if let dskRunner {
                                    if let source = dskRunner as? JSCC {
                                        ContentSourceInfoView(source: source)
                                    } else if let tracker = dskRunner as? JSCContentTracker {
                                        ContentTrackerInfoView(tracker: tracker)
                                    }
                                } else {
                                    EmptyView()
                                }
                            } label: {
                                HStack(spacing: 15) {
                                    STTThumbView(url: URL(string: runner.thumbnail))
                                        .frame(width: 44, height: 44, alignment: .center)
                                        .cornerRadius(7)
                                    VStack(alignment: .leading, spacing: 2.5) {
                                        Text(runner.name)
                                            .fontWeight(.semibold)
                                        Text(runner.version.clean)
                                            .font(.footnote.weight(.light))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if !isActive {
                                        Spacer()
                                        Image(systemName: "exclamationmark.triangle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 15)
                                            .foregroundColor(.red)
                                    }
                                
                                }
                            }
                            .disabled(!isActive)
                            .swipeActions {
                                Button {
                                    engine.removeRunner(runner.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            
                        }
                    } header: {
                        Text(key.description)
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationTitle("Installed Runners")
        .task {
            model.observe()
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
}

extension InstalledRunnersView {
    final class ViewModel: ObservableObject {
        @Published var runners: Results<StoredRunnerObject>?

        private var token: NotificationToken?

        func observe() {
            token?.invalidate()
            token = nil
            let realm = try! Realm()

            let results = realm
                .objects(StoredRunnerObject.self)
                .where { $0.isDeleted == false }
                .sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true), SortDescriptor(keyPath: "name", ascending: true)])

            token = results.observe { [weak self] _ in
                self?.runners = results.freeze()
            }
        }

        func disconnect() {
            token?.invalidate()
            token = nil
        }
    }
}
