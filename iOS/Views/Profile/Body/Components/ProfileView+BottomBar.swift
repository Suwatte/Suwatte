//
//  ProfileView+BottomBar.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-18.
//

import RealmSwift
import SwiftUI

extension ProfileView.Skeleton {
    struct BottomBar: View {
        var RNB_PCT = 0.7
        @EnvironmentObject var model: ProfileView.ViewModel

        var body: some View {
            GeometryReader { proxy in
                HStack(alignment: .center, spacing: 10) {
                    ReadNowButton()
                        .frame(width: proxy.size.width * RNB_PCT)
                    HStack(alignment: .center) {
                        ChapterListButton()
                        ActionsListButton()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            }
            .padding(.horizontal)
            .frame(height: 65)
        }
    }
}

// MARK: Chapter List

extension ProfileView.Skeleton.BottomBar {
    struct ChapterListButton: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        var body: some View {
            NavigationLink {
                ChapterList(model: model)
            } label: {
                Image(systemName: "list.bullet")
                    .font(Font.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .disabled(!model.chapterState.LOADED)
            .buttonStyle(.plain)
            .foregroundColor(.primary)
        }
    }
}

// MARK: Read Now

extension ProfileView.Skeleton.BottomBar {
    struct ReadNowButton: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @EnvironmentObject var entry: StoredContent

        var actionState: ProfileView.ViewModel.ActionState {
            model.actionState
        }

        var body: some View {
            Button {
                OpenReader()
            } label: {
                ZStack {
                    switch model.chapterState {
                    case .loaded:
                        GateWay()
                    default:
                        Text(" - ")
                    }
                }
                .padding(.horizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.fadedPrimary)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .disabled(!model.chapterState.LOADED || actionState.state == .none)
            .padding(.vertical, 5)
            .padding(.leading, 5)
        }

        @ViewBuilder
        func GateWay() -> some View {
            if actionState.state == .none {
                Text(" - ")
            } else {
                LabelForMarker()
                    .transition(.opacity)
            }
        }

        @ViewBuilder
        func LabelForMarker() -> some View {
            HStack {
                Text(actionState.state.description)
                    .font(.subheadline)
                    .bold()
                Divider()
                    .padding(.vertical)
                HStack {
                    // Chapter Information
                    VStack(alignment: .leading, spacing: 2) {
                        // Chapter Name
                        if let chapter = actionState.chapter {
                            Text(chapter.chapterName)
                                .font(.subheadline)
                                .bold()
                        }

                        // Chapter Date Read
                        if let date = actionState.marker?.date {
                            Text(date.timeAgo())
                                .font(.caption)
                                .fontWeight(.light)
                        }
                    }

                    // Progress Circle
                    if let progress = actionState.marker?.progress {
                        let color: Color = progress == 1 ? .green.opacity(0.5) : .gray
                        Circle()
                            .trim(from: 0, to: CGFloat(progress))
                            .stroke(color, style: .init(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .background(Circle().stroke(color.opacity(0.2), style: .init(lineWidth: 2.5, lineCap: .round)))
                            .frame(width: 20, height: 20, alignment: .center).padding(.horizontal, 2.5)
                    }
                }
            }
        }

        func OpenReader() {
            // Haptic
            STTHelpers.triggerHaptic()

            // State
            let progressMarker = actionState.chapter != nil ? model.readChapters[actionState.chapter!.STTContentIdentifier]?.first { $0.id == actionState.chapter!.id } : nil
            model.selection = CurrentSelection(id: actionState.chapter!.id, chapter: actionState.chapter as ThreadSafeChapter?, marker: progressMarker)
        }
    }
}

// MARK: Actions

extension ProfileView.Skeleton.BottomBar {
    struct ActionsListButton: View {
        @State private var inputImage: UIImage?
        @State private var presentImageSheet = false
        @State private var presentNextEntry = false
        @State private var selections: (DaisukeEngine.Structs.Highlight, String)?
        @EnvironmentObject var model: ProfileView.ViewModel

        var sttId: ContentIdentifier {
            model.STTIDPair
        }

        var body: some View {
            Menu {
                ReloadButton
                ManageLinkedContentButton
                MigrateButton
                SaveForLaterButton
                CustomThumbnailButton
            } label: {
                Image(systemName: "ellipsis")
                    .font(Font.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.primary)
                    .padding()
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $presentImageSheet) {
                ImagePicker(image: $inputImage)
            }

            .onChange(of: inputImage) { val in
                guard let val else { return }
                Task {
                    let actor = await RealmActor.shared()
                    await actor.setCustomThumbnail(image: val, id: sttId.id)
                }
            }
            .onChange(of: presentNextEntry, perform: { newValue in
                if !newValue {
                    selections = nil
                }
            })
            .background(
                VStack {
                    if let selections = selections {
                        NavigationLink(destination: ProfileView(entry: selections.0, sourceId: selections.1), isActive: $presentNextEntry) {
                            EmptyView()
                        }
                        .buttonStyle(.plain)
                        .frame(width: 0)
                        .opacity(0)
                    }
                }
            )
        }

        var isSavedForLater: Bool {
            model.savedForLater
        }

        var hasCustomThumb: Bool {
            StateManager
                .shared
                .titleHasCustomThumbs
                .contains(model.identifier)
        }

        var SaveForLaterButton: some View {
            Button {
                Task {
                    let actor = await RealmActor.shared()
                    await actor.toggleReadLater(sttId.sourceId, sttId.contentId)
                }
            } label: {
                Label(isSavedForLater ? "Remove from Read Later" : "Save For Later",
                      systemImage: isSavedForLater ? "circle.slash" : "clock")
            }
            .disabled(!model.source.ablityNotDisabled(\.disableLibraryActions))
        }

        @ViewBuilder
        var MigrateButton: some View {
            if model.inLibrary {
                Button { model.presentMigrationView.toggle() } label: {
                    Label("Migrate", systemImage: "tray.full")
                }
                .disabled(!model.source.ablityNotDisabled(\.disableMigrationDestination))
            }
        }

        @ViewBuilder
        var ManageLinkedContentButton: some View {
            Button {
                model.presentManageContentLinks = model.identifier
            } label: {
                Label("Linked Titles", systemImage: "link")
            }
            .disabled(!model.source.ablityNotDisabled(\.disableContentLinking))
        }

        @ViewBuilder
        var CustomThumbnailButton: some View {
            Button {
                if hasCustomThumb {
                    Task {
                        let actor = await RealmActor.shared()
                        await actor.removeCustomThumbnail(id: sttId.id)
                    }
                } else {
                    presentImageSheet.toggle()
                }
            } label: {
                Label(hasCustomThumb ? "Remove Custom Thumb" : "Set Custom Thumbnail", systemImage: "photo")
            }
            .disabled(!model.source.ablityNotDisabled(\.disableCustomThumbnails))
        }

        var ReloadButton: some View {
            Button {
                Task {
                    await model.reload()
                }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
        }
    }
}
