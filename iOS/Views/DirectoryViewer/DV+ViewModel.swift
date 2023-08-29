//
//  DV+ViewModel.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import Foundation
import SwiftUI

extension DirectoryViewer {
    final class ViewModel: ObservableObject {
        private var path: URL
        private var observer: DirectoryObserver?
        private let extensions = ["cbr", "cbz", "zip", "rar"]
        private var directorySearcher: DirectorySearcher
        @Published var directory: Folder?
        @Published var searchResultsDirectory: Folder?
        @Published var working = false
        @Published var query = "" {
            didSet {
                if query.isEmpty {
                    withAnimation {
                        searchResultsDirectory = nil
                    }
                } else { search() }
            }
        }

        init(path: URL? = nil) {
            self.path = path ?? CloudDataManager.shared.getDocumentDiretoryURL().appendingPathComponent("Library", isDirectory: true) // If path is not provided default to the base folder
            directorySearcher = DirectorySearcher(path: self.path, extensions: extensions)
        }

        func observe() {
            observer?.stop()
            let cloudEnabled = CloudDataManager.shared.isCloudEnabled
            observer = cloudEnabled ? CloudObserver(extensions: extensions, url: path) : LocalObserver(extensions: extensions, url: path)
            guard let observer else { return }

            if directory != nil { working = true } // Set as working when updating

            observer.observe { folder in
                withAnimation {
                    self.directory = folder
                    self.working = false
                }
            }
        }

        func restart() {
            stop()
            observe()
        }

        func stop() {
            observer?.stop()
            observer = nil
        }

        func search() {
            directorySearcher.search(query: query.trimmingCharacters(in: .whitespacesAndNewlines)) { [weak self] folder in
                withAnimation {
                    self?.searchResultsDirectory = folder
                }
            }
        }

        func createDirectory() {
            let ac = UIAlertController(title: "Create New Folder", message: nil, preferredStyle: .alert)
            ac.addTextField()

            let submitAction = UIAlertAction(title: "OK", style: .default) { [unowned self, unowned ac] _ in
                let text = ac.textFields![0].text?.trimmingCharacters(in: .whitespacesAndNewlines)

                guard let text else { return }
                let newFolderPath = path.appendingPathComponent(text, isDirectory: true)
                guard !newFolderPath.exists else { return }
                do {
                    try FileManager.default.createDirectory(at: newFolderPath, withIntermediateDirectories: true, attributes: nil)
                    ToastManager.shared.info("Created!")
                } catch {
                    ToastManager.shared.error(error)
                    Logger.shared.error(error)
                }
            }
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            ac.addAction(submitAction)
            KEY_WINDOW?.rootViewController?.present(ac, animated: true)
        }
    }
}

extension DirectoryViewer {
    final class CoreModel: ObservableObject {
        @Published var currentDownloadFileId: String?
        @Published var currentlyReading: File?
        private let downloader = CloudDownloader()

        func read(_: [File]) {}

        func didTapFile(_ file: File) {
            Task {
                let actor = await RealmActor.shared()
                await actor.saveArchivedFile(file)
            }
            // Generate Chapter
            let chapter = file.toReadableChapter()

            let context = ReaderState(title: file.metaData?.title ?? file.name,
                                      chapter: chapter,
                                      chapters: [chapter],
                                      requestedPage: nil,
                                      requestedOffset: nil,
                                      readingMode: nil)
            { [weak self] in
                self?.currentlyReading = nil
            }
            Task { @MainActor in
                StateManager.shared.openReader(state: context)
            }
            currentlyReading = file
        }

        func downloadAndRun(_ file: File, _ callback: @escaping (File) -> Void) {
            downloader.cancel()
            currentDownloadFileId = file.id
            downloader.download(file.url) { [weak self] result in
                do {
                    var updatedFile = try result.get().convertToSTTFile()
                    let pageCount = try? ArchiveHelper().getItemCount(for: updatedFile.url)
                    updatedFile.pageCount = pageCount
                    callback(updatedFile)
                    if self?.currentlyReading == nil {
                        self?.didTapFile(updatedFile)
                    }
                } catch {
                    ToastManager.shared.error(error)
                    Logger.shared.error(error)
                }
                self?.currentDownloadFileId = nil
            }
        }
    }
}

extension File {
    func toReadableChapter(_ idx: Int? = nil) -> ThreadSafeChapter {
        return .init(id: id,
                     sourceId: STTHelpers.LOCAL_CONTENT_ID,
                     chapterId: id,
                     contentId: id,
                     index: idx ?? 0,
                     number: metaData?.issue ?? 1,
                     volume: metaData?.volume,
                     title: metaData?.formattedName ?? name,
                     language: "unknown",
                     date: .now,
                     webUrl: nil,
                     thumbnail: nil)
    }

    func read() {
        let chapter = toReadableChapter()
        let context = ReaderState(title: metaData?.title ?? name,
                                  chapter: chapter,
                                  chapters: [chapter],
                                  requestedPage: nil,
                                  requestedOffset: nil,
                                  readingMode: nil,
                                  dismissAction: nil)
        Task {
            let actor = await RealmActor.shared()
            await actor.saveArchivedFile(self)
        }
        Task { @MainActor in
            StateManager.shared.openReader(state: context)
        }
    }
}
