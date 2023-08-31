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

        var entry: DSKCommon.Content {
            model.content
        }

        var ImageWidth = 150.0
        var body: some View {
            HStack(spacing: 10) {
                CoverImage

                VStack(alignment: .leading, spacing: 10) {
                    if let creators = entry.creators, !creators.isEmpty {
                        Text("By: \(creators.joined(separator: ", "))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                    }

                    Status
                    Text(model.source.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack(spacing: 3.5) {
                        if entry.contentType == .novel {
                            Text("Novel")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(Color.blue.opacity(0.4))
                                .cornerRadius(3)
                        }
                        if entry.isNSFW ?? false {
                            Text("NSFW")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(Color.red.opacity(0.4))
                                .cornerRadius(3)
                        }
                    }
                    

                    Spacer()
                    ActionButtons()
                }
                .padding(.vertical, 5)
                Spacer()
            }
            .frame(height: ImageWidth * 1.5, alignment: .topLeading)
            .padding(.horizontal)
        }
    }
}

// MARK: Thumbnail

extension Skeleton.Header {
    var CoverImage: some View {
        STTImageView(url: URL(string: entry.cover), identifier: model.STTIDPair)
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
            HStack(alignment: .center, spacing: 30) {
                // Library Button
                Button {
                    Task {
                        await handleLibraryAction()
                    }
                } label: {
                    Image(systemName: EntryInLibrary ? "folder.fill" : "folder.badge.plus")
                }
                .disabled(!model.source.ablityNotDisabled(\.disableLibraryActions))

                Button {
                    model.presentTrackersSheet.toggle()
                } label: {
                    Image(systemName: "checklist")
                }
                .disabled(!model.source.ablityNotDisabled(\.disableTrackerLinking))

                NavigationLink {
                    BookmarksView(contentID: model.identifier)
                } label: {
                    Image(systemName: "bookmark")
                }

                if let url = model.content.webUrl.flatMap({ URL(string: $0) }) {
                    Link(destination: url, label: {
                        Image(systemName: "globe")
                    })
                } else {
                    Button {
                    } label: {
                        Image(systemName: "globe")
                    }
                    .disabled(true)
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
