//
//  LocalFileModifier.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import SwiftUI
import UniformTypeIdentifiers

struct OpenLocalModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let types: [UTType] = [.init(filenameExtension: "cbz")!,
                           .init(filenameExtension: "cbr")!,
                           .init(filenameExtension: "zip")!,
                           .init(filenameExtension: "rar")!]
    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresenting, allowedContentTypes: types, allowsMultipleSelection: true) { result in
                let directory = CloudDataManager.shared.getDocumentDiretoryURL().appendingPathComponent("Library")
                directory.createDirectory()
                ToastManager.shared.loading = true

                switch result {
                case let .failure(error):
                    ToastManager.shared.error(error)
                case let .success(urls):
                    for url in urls {
                        let inDirectory = url.path.hasPrefix(directory.path)
                        // Only import files not already in user library
                        guard !inDirectory else {
                            continue
                        }

                        // Access Security Scoped Resource
                        guard url.startAccessingSecurityScopedResource() else {
                            continue
                        }
                        
                        defer {
                            url.stopAccessingSecurityScopedResource()
                        }

                        // Define new file location
                        let location = directory.appendingPathComponent(url.lastPathComponent)

                        // File exists at location
                        guard !location.exists else {
                            continue
                        }

                        do {
                            try FileManager.default.copyItem(at: url, to: location)
                        } catch {
                            Logger.shared.error(error)
                            ToastManager.shared.error(error)
                        }
                    }
                }
                ToastManager.shared.loading = false
            }
    }
}
