//
//  HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

import RealmSwift
import SwiftUI

private let threeMonths = Calendar.current.date(
    byAdding: .month,
    value: -3,
    to: .now
)!
struct HistoryView: View {
    @StateObject var model = ViewModel()
    @Environment(\.scenePhase) var scenePhase // Updates view when scene phase changes so URL ubiquitous download status are rechecked
    var body: some View {
        Group {
            if let markers = model.markers {
                List(markers) { marker in
                    Cell(marker: marker)
                        .listRowSeparator(.hidden)
                        .modifier(StyleModifier())
                        .modifier(DeleteModifier(id: marker.id))
                        .onTapGesture {
                            action(marker)
                        }
                }
                .transition(.opacity)
                .animation(.default, value: markers)

            } else {
                ProgressView()
                    .transition(.opacity)
            }
        }
        .modifier(InteractableContainer(selection: $model.csSelection))
        .listStyle(.plain)
        .navigationTitle("History")
        .task {
            model.observe()
        }
        .onDisappear(perform: model.disconnect)
        .onReceive(StateManager.shared.readerOpenedPublisher, perform: { _ in
            model.disconnect()
        })
        .onReceive(StateManager.shared.readerClosedPublisher, perform: { _ in
            model.observe()
        })
        .environmentObject(model)
    }
}

extension HistoryView {
    final class ViewModel: ObservableObject {
        @Published var csSelection: HighlightIdentifier?
        @Published var markers: Results<ProgressMarker>?
        @Published var currentDownloadFileId: String?
        private var downloader: CloudDownloader = .init()
        private var notificationToken: NotificationToken?
        @Published var readerLock = false

        func observe() {
            guard notificationToken == nil else { return }
            let realm = try! Realm()
            let collection = realm
                .objects(ProgressMarker.self)
                .where {
                    $0.isDeleted == false &&
                        $0.currentChapter != nil &&
                        $0.dateRead != nil &&
                        $0.dateRead >= threeMonths &&
                        ($0.currentChapter.content != nil || $0.currentChapter.opds != nil || $0.currentChapter.archive != nil)
                }
                .distinct(by: ["id"])
                .sorted(by: \.dateRead, ascending: false)
            notificationToken = collection
                .observe { _ in
                    Task { @MainActor in
                        withAnimation {
                            self.markers = collection
                        }
                    }
                }
            readerLock = false
        }

        func disconnect() {
            notificationToken?.invalidate()
            notificationToken = nil
            downloader.cancel()
            readerLock = true
        }

        func downloadAndOpen(file: File) {
            downloader.cancel()
            withAnimation {
                currentDownloadFileId = file.id
            }
            downloader.download(file.url) { [weak self] result in
                do {
                    let updatedFile = try result.get().convertToSTTFile()
                    try DataManager.shared.saveArchivedFile(updatedFile)

                    guard let self, !self.readerLock else { return }
                    updatedFile.read()
                } catch {
                    ToastManager.shared.error("An error occurred opening the archive.")
                    Logger.shared.error(error, "History")
                }
                self?.currentDownloadFileId = nil
            }
        }
    }
}

extension HistoryView {
    func action(_ marker: ProgressMarker) {
        if let content = marker.currentChapter?.content {
            if content.streamable {
                StateManager.shared.stream(item: content.toHighlight(), sourceId: content.sourceId)
            } else {
                model.csSelection = (content.sourceId, content.toHighlight())
            }
        } else if let content = marker.currentChapter?.opds {
            content.read()
        } else if let archive = marker.currentChapter?.archive {
            do {
                let file = try archive.getURL()?.convertToSTTFile()
                guard let file else {
                    throw DSK.Errors.NamedError(name: "FileManager", message: "Unable to locate file")
                }
                if !file.isOnDevice {
                    model.downloadAndOpen(file: file)
                } else {
                    file.read()
                }
            } catch {
                ToastManager.shared.error(error)
                Logger.shared.error(error)
            }
        }
    }

    struct Cell: View {
        var marker: ProgressMarker
        var body: some View {
            Group {
                if let reference = marker.currentChapter {
                    if let content = reference.content {
                        ContentSourceCell(marker: marker, content: content, chapter: reference)
                    } else if let content = reference.opds {
                        OPDSCell(marker: marker, content: content, chapter: reference)
                    } else if let content = reference.archive {
                        if let file = try? content.getURL()?.convertToSTTFile() {
                            ArchiveCell(marker: marker, archive: content, chapter: reference, file: file)
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
            .animation(.default, value: marker.progress)
        }
    }
}

extension HistoryView {
    static var transition = AnyTransition.asymmetric(insertion: .slide, removal: .scale)

    struct StyleModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)
                .contentShape(Rectangle())
        }
    }

    struct ProgressIndicator: View {
        var progress: CGFloat = 0.0
        @AppStorage(STTKeys.AppAccentColor) var color: Color = .sttDefault
        var width: CGFloat = 5.5

        var body: some View {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: .init(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: width, lineCap: .round)))
                .frame(width: 40, height: 40, alignment: .center)
        }
    }

    struct DeleteModifier: ViewModifier {
        var id: String
        func body(content: Content) -> some View {
            content
                .swipeActions(allowsFullSwipe: true, content: {
                    Button(role: .destructive) {
                        handleRemoveMarker()
                    } label: {
                        Label("Remove", systemImage: "eye.slash")
                    }
                    .tint(.red)
                })
        }

        private func handleRemoveMarker() {
            DataManager.shared.removeFromHistory(id: id)
        }
    }
}
