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
    @AppStorage(STTKeys.AppAccentColor) var accentColor : Color = .sttDefault
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleURL(_:))
                .onAppear {
                    ICDM.shared.runTasks()
                }
                .sheet(item: $navModel.identifier) { ids in
                    NavigationView {
                        ProfileView(entry: .init(contentId: ids.contentId, cover: STTHost.coverNotFound.absoluteString, title: ""), sourceId: ids.sourceId)
                            .closeButton()
                    }
                }
                .environmentObject(navModel)
                .accentColor(accentColor)
                .tint(accentColor)
        }
        
    }
}

extension SuwatteApp {
    func handleURL(_ url: URL) {
        if url.isFileURL {
            handleDirectoryPath(url)
        } else if url.scheme == "suwatte" {
            guard let host = url.host else { return }

            ToastManager.shared.display(.info("Handling URL"))
            switch host {
            case "content": // Handle Open Content
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl) else {
                    ToastManager.shared.display(.error(nil, "Unable to parse URL"))
                    break
                }
                Task {
                    await DaisukeEngine.shared.handleURL(for: url)
                }
            case "anilist":
                break // TODO: Open Anilist Profile
            case "list":
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl) else {
                        ToastManager.shared.display(.error(nil, "Unable to parse URL"))
                        break
                    }
                    Task {
                        do {
                            try await  DaisukeEngine.shared.saveRunnerList(at: url.absoluteString)
                            ToastManager.shared.info("Runner List Saved")
                        } catch {
                            ToastManager.shared.error("Failed to save Runner List: \(error.localizedDescription)")
                            Logger.shared.error("\(error)")
                        }
                    }
            default: break
            }
        }
    }

    private func handleDirectoryPath(_ url: URL) {
        switch url.pathExtension.lowercased() {
        case "json":

            do {
                try BackupManager.shared.import(from: url)
                ToastManager.shared.display(.info("File Imported"))
            } catch {
                ToastManager.shared.display(.error(error))
            }

        case "stt":

            Task {
                do {
                    try await DaisukeEngine.shared.importRunner(from: url)
                    await MainActor.run(body: {
                        ToastManager.shared.display(.info("Imported Runner!"))
                    })
                } catch {
                    ToastManager.shared.display(.error(error))
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
