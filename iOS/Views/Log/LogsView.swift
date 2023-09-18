//
//  LogsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-28.
//

import SwiftUI

struct LogsView: View {
    private let logger = Logger.shared
    @State var presenting = false
    var body: some View {
        List {
            ForEach(logger.logs) { log in
                HStack {
                    Text(log.OutputMessage.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(log.level.color)
                        .font(.caption)
                        .fontWeight(.light)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        logger.clearSession()
                        ToastManager.shared.info("Cleared Session Logs")
                    } label: {
                        Label("Clear Session Logs", systemImage: "xmark.bin")
                    }
                    Button {
                        let activityController = UIActivityViewController(activityItems: [logger.file],
                                                                          applicationActivities: nil)
                        let window = getKeyWindow()
                        window?
                            .rootViewController!
                            .present(activityController, animated: true, completion: nil)
                    } label: {
                        Label("Export Logs", systemImage: "tray.and.arrow.up")
                    }
                    Button {
                        logger.clearFile()
                        ToastManager.shared.info("Log File Cleared")

                    } label: {
                        Label("Clear Log File", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
