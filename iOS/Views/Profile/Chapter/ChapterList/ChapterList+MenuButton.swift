//
//  ChapterList+MenuButton.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import SwiftUI

extension ChapterList {
    func MenuButton() -> some View {
        Menu {
            Picker("Sort By", selection: $sortKey) {
                ForEach(filterCases) {
                    Text($0.description)
                        .tag($0)
                }
            }
            .pickerStyle(.menu)
            Button {
                sortDesc.toggle()
            } label: {
                Label("Order", systemImage: sortDesc ? "chevron.down" : "chevron.up")
            }
            Divider()
            Button {
                groupByVolume.toggle()
            } label: {
                HStack {
                    Text("Group By Volume")
                    Spacer()
                    if groupByVolume {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            Button { showOnlyDownloads.toggle() } label: {
                HStack {
                    Text("Downloaded Only")
                    Spacer()
                    if showOnlyDownloads {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Divider()
            Button { presentOptions.toggle() } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

extension ChapterList {
    @ViewBuilder
    var BottomBar: some View {
        Menu("Select") {
            Button("Select All") { selectAll() }
            Button("Deselect All") { deselectAll() }
            Divider()
            Button("Fill Range") { fillRange() }
            Button("Invert Selection") { invertSelection() }
            Divider()
            Button("Select All Below") { selectBelow() }
            Button("Select All Above") { selectAbove() }
        }
        Spacer()
        Menu("Mark") {
            Button("Read") { markAsRead() }
            Button("Unread") { markAsUnread() }
        }
        Spacer()
        Menu("Options") {
            Button("Download Chapter(s)") { addToDownloadQueue() }
            Button("Delete / Cancel Download(s)", role: .destructive) { removeDownload() }
            Divider()
            Button("Reset Chapter Data", role: .destructive) { clearChapterData() }
        }
    }
}
