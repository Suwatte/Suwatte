//
//  HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-01.
//

import RealmSwift
import SwiftUI

struct HistoryView: View {
    @StateObject var model = ViewModel()
    @Environment(\.scenePhase) var scenePhase // Updates view when scene phase changes so URL ubiquitous download status are rechecked
    @State var isUserViewing = false
    var body: some View {
        ZStack {
            List(model.markers) { marker in
                Cell(marker: marker)
                    .listRowSeparator(.hidden)
                    .modifier(StyleModifier())
                    .modifier(DeleteModifier(id: marker.id))
                    .onTapGesture {
                        action(marker)
                    }
            }
            .animation(.default, value: model.markers)
            .opacity(model.markers.isEmpty ? 0 : 1)
            .transition(.opacity)

            ProgressView()
                .opacity(model.dataFetchComplete ? 0 : 1)
                .transition(.opacity)


            VStack {
                Text("(￣ε￣＠)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Titles you read will show up here")
                    .font(.subheadline)
                    .fontWeight(.light)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.gray)
            .opacity(model.markers.isEmpty && model.dataFetchComplete ? 1 : 0)
            .transition(.opacity)

        }
        .modifier(InteractableContainer(selection: $model.csSelection))
        .listStyle(.plain)
        .navigationTitle("History")
        .task {
            isUserViewing = true
            await model.observe()
        }
        .onDisappear {
            isUserViewing = false
            model.disconnect()
        }
        .onReceive(StateManager.shared.readerOpenedPublisher, perform: { _ in
            if isUserViewing {
                model.disconnect()
            }
        })
        .onReceive(StateManager.shared.readerClosedPublisher, perform: { _ in
            if isUserViewing {
                Task {
                    await model.observe()
                }
            }
        })
        .environmentObject(model)
        .animation(.default, value: model.markers)
        .animation(.default, value: model.dataFetchComplete)
    }
}

extension HistoryView {
    final class ViewModel: ObservableObject {
        @Published var csSelection: HighlightIdentifier?
        @Published var markers: [ProgressMarker] = []
        @Published var currentDownloadFileId: String?
        private var downloader: CloudDownloader = .init()
        private var notificationToken: NotificationToken?
        @Published var readerLock = false
        @Published var dataFetchComplete = false
        func observe() async {
            guard notificationToken == nil else { return }
            let actor = await RealmActor.shared()
            notificationToken = await actor.observeHistory { value in
                Task { @MainActor in
                    withAnimation { [weak self] in
                        self?.markers = value
                        self?.dataFetchComplete = true
                    }
                }
            }
            await MainActor.run {
                readerLock = false
            }
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
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.saveArchivedFile(updatedFile)
                    }

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
            Task {
                let actor = await RealmActor.shared()
                await actor.removeFromHistory(id: id)
            }
        }
    }
}
