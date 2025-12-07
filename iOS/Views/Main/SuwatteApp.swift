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
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL(perform: handleURL(_:))
                .environmentObject(navModel)
                .accentColor(accentColor)
                .tint(accentColor)
                .task {
                    await DSK.shared.getCommons()
                }
                .task {
                    await SDM.shared.appDidStart()
                }
        }
    }
}

extension SuwatteApp {
    func handleURL(_ url: URL) {
        if url.isFileURL {
            handleDirectoryPath(url)
        } else if url.scheme == "suwatte" {
            guard let host = url.host else { return }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

            switch host {
            case "deeplink": // Handle Open Content
                guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl) else {
                    ToastManager.shared.display(.error(nil, "Unable to parse URL"))
                    break
                }
                Task {
                    await DSK.shared.handleURL(for: url)
                }
            case "list":
                guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl) else {
                    ToastManager.shared.display(.error(nil, "Unable to parse URL"))
                    break
                }
                Task {
                    do {
                        try await DSK.shared.saveRunnerList(at: url.absoluteString)
                        ToastManager.shared.info("Runner List Saved")
                    } catch {
                        ToastManager.shared.error("Failed to save Runner List: \(error.localizedDescription)")
                        Logger.shared.error("\(error)")
                    }
                }
            case "runner":
                guard let contentUrl = components?.queryItems?.first(where: { $0.name == "url" })?.value, let url = URL(string: contentUrl), let runner = components?.queryItems?.first(where: { $0.name == "runner" })?.value else {
                    ToastManager.shared.display(.error(nil, "Unable to parse URL"))
                    return
                }
                Task {
                    do {
                        try await DSK.shared.importRunner(from: url, with: runner)
                    } catch {
                        ToastManager.shared.error("Failed to save Runner List: \(error.localizedDescription)")
                        Logger.shared.error(error)
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
                    try await DSK.shared.importRunner(from: url)
                    await MainActor.run(body: {
                        ToastManager.shared.display(.info("Imported Runner!"))
                    })
                } catch {
                    ToastManager.shared.display(.error(error))
                }
            }
        case "zip", "cbz", "rar", "cbr":
            STTHelpers.importArchiveFie(at: url)
        default:
            Logger.shared.info("Suwatte has not defined a handler for this file type")
        }
    }
}

final class NavigationModel: ObservableObject {
    static let shared = NavigationModel()
    @Published var content: TaggedHighlight?
    @Published var link: TaggedPageLinkLabel?
}

extension ContentIdentifier: Identifiable {}
extension STTHelpers {
    static func importArchiveFie(at url: URL) {
        let validExtensions = ["cbz", "cbr", "rar", "zip"]
        let canHandle = validExtensions.contains(url.pathExtension)
        guard canHandle else { return }
        let directory = CloudDataManager.shared.getDocumentDiretoryURL().appendingPathComponent("Library")
        directory.createDirectory()
        let inDirectory = url.path.hasPrefix(directory.path)

        var final: URL?
        if !inDirectory {
            ToastManager.shared.loading = true
            // Move to Library
            let location = directory.appendingPathComponent(url.lastPathComponent)
            if location.exists {
                StateManager.shared.alert(title: "Import", message: "This file already exists in your library")
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            do {
                try FileManager.default.copyItem(at: url, to: location)
                Logger.shared.log("Imported \(url.fileName)")
                final = location
            } catch {
                Logger.shared.error(error)
                ToastManager.shared.error(error)
            }
            ToastManager.shared.loading = false
        } else {
            final = url
        }
        guard StateManager.shared.readerState == nil, let final else { return }
        final.buildFileInfo().read()
    }
}
