//
//  BackupsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

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

    var body: some View {
        List {
            ForEach(manager.urls, id: \.path) { url in
                Button(url.deletingPathExtension().lastPathComponent) {
                    selection = url
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
                            saveNewBackup()
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
    func saveNewBackup() {
        ToastManager.shared.loading.toggle()
        defer {
            ToastManager.shared.loading.toggle()
        }
        do {
            try BackupManager.shared.save()
        } catch {
            Logger.shared.error("[Backup] [Save New] \(error.localizedDescription)")
            ToastManager.shared.error(error)
        }
    }

    func handleShareURL(url: URL) {
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        KEY_WINDOW?.rootViewController!.present(activityController, animated: true, completion: nil)
    }

    func handleRestore(url: URL) {
        ToastManager.shared.loading.toggle()

        restoreTask = Task {
            do {
                if !ICDM.shared.isIdle {
                    throw DSK.Errors.NamedError(name: "ERROR", message: "Active Downloads")
                }
                try await manager.restore(from: url)

                await MainActor.run(body: {
                    ToastManager.shared.loading.toggle()
                    ToastManager.shared.info("Restored Backup!")
                })

            } catch {
                Logger.shared.error("[BackUpView] [Restore] \(error)")
                await MainActor.run(body: {
                    ToastManager.shared.error(error)
                })
            }
        }
    }
}
