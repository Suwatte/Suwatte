//
//  BackupsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Combine
import SwiftUI

struct BackupsView: View {
    @StateObject var manager = BackupManager.shared
    @State var selection: URL? {
        didSet {
            presentActions.toggle()
        }
    }

    @State var presentActions = false
    @State var presentAlert = false
    @State var presentImporter = false
    @State var restoreTask: Task<Void, Never>? = nil
    private let downloader = CloudDownloader()
    var body: some View {
        List {
            ForEach(manager.urls, id: \.path) { url in
                Button {
                    selection = url
                } label: {
                    Text(url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .punctuationCharacters))
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        manager.remove(url: url)
                    }
                }
            }
        }
        .confirmationDialog("Actions", isPresented: $presentActions) {
            Button("Export") {
                // Share Sheet
                handleShareURL(url: selection!)
            }
            Button("Restore", role: .destructive) {
                presentAlert.toggle()
            }
        }
        .alert("Restoring \(selection?.deletingPathExtension().lastPathComponent ?? "")\nThis action cannot be undone and all current data will be lost. If this is not a fresh install, please backup your data.", isPresented: $presentAlert) {
            Button("Cancel", role: .cancel) {}
            if let selection = selection {
                Button("Restore", role: .destructive) {
                    handleRestore(url: selection)
                }
            }
        }
        .navigationTitle("Backups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task {
                            await saveNewBackup()
                        }
                    } label: {
                        Label("Create Backup", systemImage: "plus")
                    }

                    Button { presentImporter.toggle() } label: {
                        Label("Import Backup", systemImage: "tray.and.arrow.down.fill")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .animation(.default, value: manager.urls)
        .fileImporter(isPresented: $presentImporter, allowedContentTypes: [.json], onCompletion: { result in
            switch result {
            case let .success(url):
                if url.startAccessingSecurityScopedResource() {
                    // Copy To Local Document
                    do {
                        try BackupManager.shared.import(from: url)
                        ToastManager.shared.info("Imported Backup")
                    } catch {
                        ToastManager.shared.error(error)
                    }
                    url.stopAccessingSecurityScopedResource()
                }

            case let .failure(error):
                ToastManager.shared.error(error)
            }
        })
        .protectContent()
    }
}

extension BackupsView {
    func saveNewBackup() async {
        ToastManager.shared.block {
            try await BackupManager.shared.save()
        }
    }

    func handleShareURL(url: URL) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        let window = getKeyWindow()
        window?.rootViewController!.present(activityController, animated: true, completion: nil)
    }

    func handleRestore(url: URL) {
        ToastManager.shared.loading = true

        restoreTask = Task {
            do {
                try await manager.restore(from: url)
                await MainActor.run(body: {
                    ToastManager.shared.loading = false
                    ToastManager.shared.info("Restored Backup!")
                })
            } catch {
                Logger.shared.error("[BackUpView] [Restore] \(error)")
                await MainActor.run(body: {
                    ToastManager.shared.error(error)
                    ToastManager.shared.loading = false
                })
            }
        }
    }
}
