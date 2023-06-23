//
//  Browse+LocalSection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-07.
//

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
