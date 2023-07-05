//
//  DV+DownloadQueue.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-24.
//

import SwiftUI
import Alamofire
import Nuke
extension DirectoryViewer {
    final class DownloadManager : ObservableObject {
        
        static let shared = DownloadManager.init()
        @Published var downloads: [DownloadObject] = []
        private let finalDirectory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("STTDownloads", isDirectory: true)
        private let tempDirecotry = FileManager.default.documentDirectory.appendingPathComponent("__temp__")
        func startDownloadQueue() {
            if let first = downloads.first {
                startDownload(first)
            } else {
                deleteTemp()
            }
        }
        
        func didFinishLastDownload() {
            guard let target = downloads.popFirst() else {
                deleteTemp()
                return
            }
            
            if target.status == .failing {
                target.timestamp = .now
                downloads.append(target)
            }
            
            // New Item At Top, Restart
            startDownloadQueue()
        }
        
        func deleteTemp() {
            if tempDirecotry.contents.isEmpty {
                try? FileManager.default.removeItem(at: tempDirecotry)
            }
        }
        
        func addToQueue(_ download: DownloadObject) {
            downloads.append(download)
            
            if downloads.count == 1 {
                startDownloadQueue()
            }
        }
        
        func removeFromQueue(_ download: DownloadObject) {
            if download.status == .active {
                download.cancel()
            }
            let index = downloads.firstIndex(where: { $0.request == download.request })
            guard let index else { return }
            if index != 1 {
                downloads.remove(at: index)
            }
        }
        
        func startDownload(_ download: DownloadObject) {
            if download.status != .queued {
                _ = downloads.popFirst()
                didFinishLastDownload()
            }
            
            let downloadPath = tempDirecotry.appendingPathComponent(download.url.lastPathComponent)
            let destination: DownloadRequest.Destination = { _, _ in
                (downloadPath, [.removePreviousFile, .createIntermediateDirectories])
            }
            
            let final = finalDirectory.appendingPathComponent(download.url.lastPathComponent)
            download.status = .active
            let req = AF
                .download(download.request, to: destination)
                .downloadProgress { progress in
                    download.progress = progress.fractionCompleted
                }
                .response { response in
                    do {
                        let url = try response.result.get()
                        if let url {
                            try FileManager.default.moveItem(at: url, to: final)
                        }
                        download.status = .completed
                    } catch {
                        download.status = .failing
                    }
                    self.didFinishLastDownload()
                }
            download.setRequest(req)
        }
    }
    
}

extension DirectoryViewer.DownloadManager {
    final class DownloadObject : ObservableObject {
        var url: URL
        var request: URLRequest
        var title: String
        var thumbnailReqeust: URLRequest
        var status: DownloadStatus = .queued
        var timestamp = Date.now
        var progress: Double = .zero
        
        private var downloadRequest: DownloadRequest?
        
        init(url: URL, request: URLRequest, title: String, thumbnailReqeust: URLRequest) {
            self.url = url
            self.title = title
            self.thumbnailReqeust = thumbnailReqeust
            self.request = request
        }
        
        func cancel() {
            downloadRequest?.cancel()
            status = .cancelled
        }
        
        func setRequest(_ req: DownloadRequest) {
            downloadRequest = req
        }
    }
}
extension DirectoryViewer {
    struct DownloadQueueSheet: View {
        @StateObject var manager: DirectoryViewer.DownloadManager = .shared
        var body: some View {
            NavigationView {
                List {
                    Section {
                        ForEach(manager.downloads, id: \.url) { download in
                            Tile(download: download)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        manager.removeFromQueue(download)
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                        }
                    }
                }
                .navigationTitle("Local Downloads")
                .closeButton()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Cancel All", role: .destructive) {
                                manager.downloads.forEach { manager.removeFromQueue($0) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
}


extension DirectoryViewer.DownloadQueueSheet {
    struct Tile: View {
        @ObservedObject var download: DirectoryViewer.DownloadManager.DownloadObject
        
        let size = CGFloat(80)
        var body: some View {
            HStack {
                // TODO: Change this to use the STTImageView
                BaseImageView(request: .init(urlRequest: download.thumbnailReqeust))
                .frame(minWidth: 0, idealWidth: size, maxWidth: size, minHeight: 0, idealHeight: size * 1.5, maxHeight: size * 1.5, alignment: .center)
                .scaledToFit()
                .background(Color.fadedPrimary)
                .cornerRadius(5)
                
                VStack {
                    Text(download.title)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }
                Spacer()
                HistoryView.ProgressIndicator(progress: download.progress)
            }
        }
    }
}


