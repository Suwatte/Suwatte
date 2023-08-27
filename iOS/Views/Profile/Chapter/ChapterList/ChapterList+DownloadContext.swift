//
//  ChapterList+DownloadContext.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import SwiftUI

extension ChapterList {
    struct DownloadContextView: View {
        let id: String
        let status: DownloadStatus
        var body: some View {
            Group {
                switch status {
                case .cancelled:
                    EmptyView()
                case .idle, .queued:
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Cancel Download", systemImage: "x.circle")
                    }
                case .completed:
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Delete Download", systemImage: "trash.circle")
                    }
                case .active:
                    Group {
                        Button(role: .destructive) {
                            Task {
                                await SDM.shared.cancel(ids: [id])
                            }

                        } label: {
                            Label("Cancel Download", systemImage: "x.circle")
                        }
                        Button {
                            Task {
                                await SDM.shared.pause(ids: [id])
                            }
                        } label: {
                            Label("Pause Download", systemImage: "pause.circle")
                        }
                    }
                case .paused:
                    Button {
                        Task {
                            await SDM.shared.resume(ids: [id])
                        }
                    } label: {
                        Label("Resume Download", systemImage: "play.circle")
                    }
                case .failing:
                    Button {
                        Task {
                            await SDM.shared.resume(ids: [id])
                        }
                    } label: {
                        Label("Retry Download", systemImage: "arrow.counterclockwise.circle")
                    }
                    Button(role: .destructive) {
                        Task {
                            await SDM.shared.cancel(ids: [id])
                        }
                    } label: {
                        Label("Cancel Download", systemImage: "x.circle")
                    }
                }
            }
        }
    }
}

