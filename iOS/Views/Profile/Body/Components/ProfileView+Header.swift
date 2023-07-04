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
            HStack {
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
                    if let ac = entry.adultContent, ac {
                        Text("18+")
                            .font(.caption)
                            .fontWeight(.light)
                            .padding(.all, 2)
                            .background(Color.red.opacity(0.4))
                            .cornerRadius(5)
                    }

                    Spacer()
                    ActionButtons()
                }
                .padding(.vertical, 5)
                Spacer()
            }
            .frame(height: ImageWidth * 1.5)
            .padding(.horizontal)
        }
    }
}

// MARK: Thumbnail

extension Skeleton.Header {
    var CoverImage: some View {
        STTImageView(url: URL(string: entry.cover), identifier: model.sttIdentifier())

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
        @State var currentAction: Option?
        @State var presentSafariView = false
        @EnvironmentObject var model: ProfileView.ViewModel
        @AppStorage(STTKeys.AlwaysAskForLibraryConfig) var promptForConfig = true
        @AppStorage(STTKeys.DefaultCollection) var defaultCollection: String = ""
        @AppStorage(STTKeys.DefaultReadingFlag) var defaultFlag = LibraryFlag.unknown
        var body: some View {
            HStack(alignment: .center, spacing: 30) {
                ForEach(actions, id: \.option) { action in

                    Button {
                        switch action.option {
                        case .COLLECTIONS:
                            STTHelpers.triggerHaptic(true)
                            if !EntryInLibrary {
                                DataManager.shared.toggleLibraryState(for: model.storedContent)
                            }
                            if promptForConfig || EntryInLibrary {
                                model.presentCollectionsSheet.toggle()
                            } else {
                                if !defaultCollection.isEmpty {
                                    DataManager.shared.toggleCollection(for: model.contentIdentifier, withId: defaultCollection)
                                }

                                if defaultFlag != .unknown {
                                    var s = Set<String>()
                                    s.insert(model.contentIdentifier)
                                    DataManager.shared.bulkSetReadingFlag(for: s, to: defaultFlag)
                                }
                            }
                        case .TRACKERS: model.presentTrackersSheet.toggle()
                        case .WEBVIEW: model.presentSafariView.toggle()
                        case .BOOKMARKS: model.presentBookmarksSheet.toggle()
                        }
                    } label: {
                        Image(systemName: action.imageName)
                    }
                    .disabled(action.option == .WEBVIEW && model.content.webUrl == nil)
                }
            }

            .font(.title2.weight(.light))
        }

        var EntryInLibrary: Bool {
            model.inLibrary
        }
    }
}

private extension Skeleton.ActionButtons {
    var actions: [Action] {
        [.init(imageName: EntryInLibrary ? "folder.fill" : "folder.badge.plus", option: .COLLECTIONS),
         .init(imageName: "checklist", option: .TRACKERS),
         .init(imageName: "bookmark", option: .BOOKMARKS),
         .init(imageName: "globe", option: .WEBVIEW)]
    }

    enum Option: Identifiable {
        case COLLECTIONS, BOOKMARKS, TRACKERS, WEBVIEW

        var id: Int {
            hashValue
        }
    }

    struct Action {
        var imageName: String
        var option: Option
    }
}