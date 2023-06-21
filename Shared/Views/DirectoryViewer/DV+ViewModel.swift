//
//  DV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation


extension DirectoryViewer {
    final class ViewModel: ObservableObject {
        
        private var path: URL
        private var observer: DirectoryObserver?

        @Published var folder: Folder?
        
        init(path: URL? = nil) {
            self.path = path ?? CloudDataManager.shared.getDocumentDiretoryURL().appendingPathComponent("Library") // If path is not provided default to the base folder
        }
        
        func observe() {
            observer?.stop()
            let cloudEnabled = CloudDataManager.shared.isCloudEnabled
            observer = CloudObserver(extensions: ["cbr"], url: path)
            guard let observer else { return }
            observer.observe { folder in
                self.folder = folder
            }
        }

        func stop() {
            observer?.stop()
            observer = nil
        }
    }
}

