//
//  StatisticsView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-13.
//

import SwiftUI

struct LoadableStatisticsView: View {
    @State private var loadable: Loadable<LibraryStatistics> = .idle
    var body: some View {
        LoadableView(load, $loadable) { value in
            LibraryStatisticsView(statistics: value)
        }
        .transition(.opacity)
        .navigationTitle("Library Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .closeButton()
        .animation(.default, value: loadable)
    }

    func load() async -> LibraryStatistics {
        await RealmActor.shared().getLibraryStatistics()
    }
}

struct LibraryStatisticsView: View {
    let statistics: LibraryStatistics
    var body: some View {
        List {
            Section {
                Text("Total Library Count")
                    .badge(statistics.total.description)
            } header: {
                Text("General")
            }

            // Runners
            if !statistics.runners.isEmpty {
                Section {
                    ForEach(statistics.runners.sorted(by: \.value), id: \.key) { key, value in
                        HStack {
                            STTThumbView(url: URL(string: key.thumbnail))
                                .frame(width: 44, height: 44)
                                .cornerRadius(7)
                            Text(key.name)
                        }
                        .badge(value.description)
                    }
                } header: {
                    Text("Sources")
                }
            }

            // Status
            if !statistics.status.isEmpty {
                Section {
                    ForEach(statistics.status.sorted(by: \.value), id: \.key) { key, value in
                        Text(key.description)
                            .badge(value.description)
                    }
                } header: {
                    Text("Publication Status")
                }
            }

            // Flag
            if !statistics.flag.isEmpty {
                Section {
                    ForEach(statistics.flag.sorted(by: \.value), id: \.key) { key, value in
                        Text(key.description)
                            .badge(value.description)
                    }
                } header: {
                    Text("Reading Flag")
                }
            }

            // Type
            if !statistics.type.isEmpty {
                Section {
                    ForEach(statistics.type.sorted(by: \.value), id: \.key) { key, value in
                        Text(key.description)
                            .badge(value.description)
                    }
                } header: {
                    Text("Content Type")
                }
            }

            Section {
                Text("Bookmarks Added")
                    .badge(statistics.bookmarks.description)

                Text("Collections")
                    .badge(statistics.collections.description)

                Text("Downloads")
                    .badge(statistics.downloads.description)

                Text("Saved For Later")
                    .badge(statistics.savedForLater.description)

                Text("NSFW Titles")
                    .badge(statistics.nsfw.description)
                Text("Custom Thumbanils")
                    .badge(statistics.customThumbnails.description)

                Text("Opened Titles")
                    .badge(statistics.openedTitles.description)
            } header: {
                Text("Misc")
            }

            Section {
                Text("Chapters Read")
                    .badge(statistics.chaptersRead.description)
                Text("Panels Read")
                    .badge(statistics.pagesRead.description)

                Text("Meters Scrolled")
                    .badge("\(convertPixelsToMeters(pixels: statistics.pixelsScrolled).clean) Meters")
            } header: {
                Text("Chapters")
            }

            if !statistics.tags.isEmpty {
                let upperBound = Int(Double(statistics.total) * 0.75)
                let lowerBound = Int(Double(statistics.total) * 0.15)
                Section {
                    ForEach(statistics.tags.sorted(by: \.value), id: \.key) { key, value in
                        Text(key.capitalized)
                            .fontWeight(value >= upperBound ? .semibold : value <= lowerBound ? .light : .regular)
                            .badge(value.description)
                    }
                } header: {
                    Text("Tags")
                }
            }
        }
        .headerProminence(.increased)
    }

    func convertPixelsToMeters(pixels: Double) -> Double {
        let millimetersPerPixel = 0.352778
        let millimeters = pixels * millimetersPerPixel
        let kilometers = millimeters / 1000
        return kilometers
    }
}
