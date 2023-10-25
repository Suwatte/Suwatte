//
//  ProfileView+Header.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import RealmSwift
import SwiftUI

private typealias Skeleton = ProfileView.Skeleton

extension Skeleton {
    struct Header: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @State var presentThumbnails = false
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        @State var labels: [ColoredLabel] = []
        @Environment(\.colorScheme) var colorScheme
        var entry: DSKCommon.Content {
            model.content
        }

        var ImageWidth = 150.0
        var body: some View {
            HStack(spacing: 10) {
                CoverImage
                VStack(alignment: .leading, spacing: 10) {
                    LabelsView
                        .frame(height: ImageWidth, alignment: .topLeading)
                        .clipped()
                    Spacer()
                    ActionButtons()
                }
                .padding(.vertical, 1.5)
            }
            .frame(height: ImageWidth * 1.5, alignment: .topLeading)
            .task {
                guard labels.isEmpty else { return }
                labels = buildLabels()
            }
            .onChange(of: model.content, perform: { value in
                labels = buildLabels()
            })
        }
    }
}

extension Skeleton.Header {
    func buildLabels() -> [ColoredLabel] {
        var data = [ColoredLabel]()

        if let creators = entry.creators, !creators.isEmpty {
            data.append(contentsOf: creators.prefix(2).map { .init(text: $0, color: .accentColor) })
        }

        if let status = entry.status {
            data.append(.init(text: status.description, color: status.color))
        }

        data.append(.init(text: model.source.name, color: .accentColor))

        if let contentType = entry.contentType {
            data.append(.init(text: contentType.description, color: contentType == .novel ? .blue : .accentColor))
        }

        if entry.isNSFW ?? false {
            data.append(.init(text: "NSFW", color: .red))
        }

        if let info = entry.info {
            data.append(contentsOf: info.prefix(5).map { .init(text: $0, color: .accentColor) })
        }

        return data
    }

    @ViewBuilder
    var LabelsView: some View {
        let schemeIsDark = colorScheme == .dark
        InteractiveTagView(labels) { label in
            Text(label.text)
                .font(.caption2)
                .fontWeight(schemeIsDark ? .semibold : .bold)
                .lineLimit(1)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(label.color.opacity(schemeIsDark ? 0.65 : 0.95))
                .foregroundColor(.white)
                .cornerRadius(3)
        }
    }
}

// MARK: Thumbnail

extension Skeleton.Header {
    var imageURL: URL? {
        URL(string: model.contentState.LOADED ? model.content.cover : model.entry.cover)
    }

    var CoverImage: some View {
        STTImageView(url: imageURL, identifier: model.STTIDPair)
            .frame(width: ImageWidth, height: ImageWidth * 1.5)
            .cornerRadius(7)
            .shadow(radius: 3)
            .onTapGesture {
                presentThumbnails.toggle()
            }
            .fullScreenCover(isPresented: $presentThumbnails) {
                ProfileView.CoversSheet(covers: entry.covers)
                    .accentColor(accentColor)
                    .tint(accentColor)
            }
    }
}

// MARK: Status

extension Skeleton.Header {
    var entryStatus: ContentStatus {
        entry.status ?? .UNKNOWN
    }

    var Status: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
            Text("\(entryStatus.description)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(entryStatus.color)
    }
}

// MARK: Actions

private extension Skeleton {
    struct ActionButtons: View {
        @State var presentSafariView = false
        @EnvironmentObject var model: ProfileView.ViewModel
        @AppStorage(STTKeys.AlwaysAskForLibraryConfig) var promptForConfig = true
        @AppStorage(STTKeys.DefaultCollection) var defaultCollection: String = ""
        @AppStorage(STTKeys.DefaultReadingFlag) var defaultFlag = LibraryFlag.unknown
        var body: some View {
            HStack(alignment: .center) {
                // Library Button
                
                if model.source.ablityNotDisabled(\.disableLibraryActions) {
                    
                    Button {
                        Task {
                            await handleLibraryAction()
                        }
                    } label: {
                        Image(systemName: EntryInLibrary ? "folder.fill" : "folder.badge.plus")
                    }
                    Spacer()

                }

                
                if model.source.ablityNotDisabled(\.disableTrackerLinking) {
                    Button {
                        model.presentTrackersSheet.toggle()
                    } label: {
                        Image(systemName: "checklist")
                    }
                    Spacer()

                }
                
                NavigationLink {
                    BookmarksView(contentID: model.identifier)
                } label: {
                    Image(systemName: "bookmark")
                }


                if let url = model.content.webUrl.flatMap({ URL(string: $0) }) {
                    Spacer()
                    Link(destination: url, label: {
                        Image(systemName: "globe")
                    })
                }
            }

            .font(.title2.weight(.light))
        }

        var EntryInLibrary: Bool {
            model.inLibrary
        }

        func handleLibraryAction() async {
            let actor = await RealmActor.shared()
            Task { @MainActor in
                STTHelpers.triggerHaptic(true)
            }
            let ids = model.STTIDPair
            if !EntryInLibrary {
                await actor.toggleLibraryState(for: ids)
            }
            if promptForConfig || EntryInLibrary {
                model.presentCollectionsSheet.toggle()
            } else {
                if !defaultCollection.isEmpty {
                    await actor.toggleCollection(for: model.identifier,
                                                 withId: defaultCollection)
                }

                if defaultFlag != .unknown {
                    var s = Set<String>()
                    s.insert(model.identifier)
                    await actor.bulkSetReadingFlag(for: s, to: defaultFlag)
                }
            }
        }
    }
}
