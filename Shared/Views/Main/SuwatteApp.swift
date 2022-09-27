//
//  SuwatteApp.swift
//  Shared
//
//  Created by Mantton on 2022-02-28.
//

import SwiftUI

@main
struct SuwatteApp: App {
    @UIApplicationDelegateAdaptor(STTAppDelegate.self) var AppDelegate
    @StateObject var navModel = NavigationModel.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleURL(_:))
                .onAppear {
                    //                    DownloadManager.shared.reloadTasks()
                }
                .sheet(item: $navModel.identifier) { ids in
                    NavigationView {
                        ProfileView(entry: .init(contentId: ids.contentId, cover: STTHost.coverNotFound.absoluteString, title: ""), sourceId: ids.sourceId)
                            .closeButton()
                    }
                }
                .environmentObject(navModel)
        }
    }
}

extension SuwatteApp {
    func handleURL(_ url: URL) {
        if url.isFileURL {
            handleDirectoryPath(url)
        } else if url.scheme == "suwatte" {
            guard let host = url.host else { return }

            ToastManager.shared.toast = .init(displayMode: .alert, type: .loading)
            switch host {
            case "content": // Handle Open Content
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl) else {
                    ToastManager.shared.setError(msg: "Could not parse URL")
                    break
                }
                Task {
                    await DaisukeEngine.shared.handleURL(for: url)
                }
            case "anilist":
                break // TODO: Open Anilist Profile
            case "list": // TODO: Add Source List
                break
            default: break
            }

            ToastManager.shared.show = false
        }
    }

    private func handleDirectoryPath(_ url: URL) {
        switch url.pathExtension.lowercased() {
        case "json":

            do {
                try BackupManager.shared.import(from: url)
                ToastManager.shared.setToast(toast: .init(type: .complete(.green), title: "File Imported"))

            } catch {
                ToastManager.shared.setError(error: error)
            }

        case "stt":

            Task {
                do {
                    try await DaisukeEngine.shared.importRunner(from: url)
                    await MainActor.run(body: {
                        ToastManager.shared.setToast(toast: .init(type: .complete(.green), title: "Imported!"))
                    })
                } catch {
                    ToastManager.shared.setError(error: error)
                }
            }

        default: break
        }
    }
}

final class NavigationModel: ObservableObject {
    static let shared = NavigationModel()
    @Published var identifier: ContentIdentifier?
}

extension ContentIdentifier: Identifiable {}
