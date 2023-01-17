//
//  Browse+LocalSection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

import Kingfisher
import SwiftUI
import UniformTypeIdentifiers

struct OpenLocalModifier: ViewModifier {
    @Binding var isPresenting: Bool
    let types: [UTType] = [.init(filenameExtension: "cbz")!, .init(filenameExtension: "cbr")!]
    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresenting, allowedContentTypes: types, allowsMultipleSelection: true) { result in
                switch result {
                case let .failure(error):
                    ToastManager.shared.error(error)
                case let .success(urls):
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            do {
                                try LocalContentManager.shared.importFile(at: url)
                            } catch {
                                ToastManager.shared.error(error)
                            }
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                }
            }
    }
}

let serialQueue = DispatchQueue(label: "com.suwatte.unarchiver")
struct LocalContentImageProvider: ImageDataProvider {
    var cacheKey: String
    var fileId: String
    var pagePath: String?
    init(cacheKey: String, fileId: String, pagePath: String) {
        self.cacheKey = cacheKey
        self.fileId = fileId
        self.pagePath = pagePath
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        serialQueue.async {
            do {
                guard let pagePath = pagePath else {
                    handler(.failure(DaisukeEngine.Errors.LocalFilePathNotFound))
                    return
                }
                let data = try LocalContentManager.shared.getImageData(for: fileId, ofName: pagePath)
                DispatchQueue.main.async {
                    handler(.success(data))
                }

            } catch {
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }
        }
    }
}

struct LocalContentImageSwiftUIProvider: ImageDataProvider {
    var cacheKey: String
    let fileId: String
    let entryPath: String
    init(fileId: String, entryPath: String) {
        cacheKey = "\(fileId)||\(entryPath)" // Doesn't matter as the image is not cached for performance reasons
        self.fileId = fileId
        self.entryPath = entryPath
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try LocalContentManager.shared.getImageData(for: fileId, ofName: entryPath)
                handler(.success(data))

            } catch {
                handler(.failure(error))
            }
        }
    }
}
