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
                ChapterList()
                    .environmentObject(model)
                    .defaultAppStorage(.init(suiteName: model.sttIdentifier().id) ?? .standard)
            } label: {
                Image(systemName: "list.bullet")
                    .font(Font.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .disabled(!model.chapters.LOADED)
            .buttonStyle(.plain)
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
                    switch model.chapters {
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
                .padding(.vertical, 5)
            }
            .disabled(!model.chapters.LOADED || actionState.state == .none)
            .buttonStyle(.plain)
        }

        @ViewBuilder
        func GateWay() -> some View {
            if actionState.state == .none {
                Text(" - ")
            } else {
                LabelForMarker()
                    .transition(.move(edge: .bottom))
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
                            Text("Chapter \(chapter.number.clean)")
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
            model.selection = actionState.chapter?._id
        }
    }
}

// MARK: Actions

extension ProfileView.Skeleton.BottomBar {
    struct ActionsListButton: View {
        @ObservedResults(CustomThumbnail.self) var thumbnails
        @ObservedResults(ContentLink.self) var contentLinks
        @State private var inputImage: UIImage?
        @State private var presentImageSheet = false
        @State private var presentNextEntry = false
        @State private var selections: (DaisukeEngine.Structs.Highlight, String)?
        @EnvironmentObject var model: ProfileView.ViewModel

        var sttId: ContentIdentifier {
            model.sttIdentifier()
        }

        var body: some View {
            Menu {
                ManageLinkedContentButton
                MigrateButton
                SaveForLaterButton
                CustomThumbnailButton
            } label: {
                Image(systemName: "ellipsis")
                    .font(Font.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color.primary)
                    .padding()
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $presentImageSheet) {
                ImagePicker(image: $inputImage)
            }

            .onChange(of: inputImage) { val in
                if let val = val {
                    DataManager.shared.setCustomThumbnail(image: val, id: model.sttIdentifier().id)
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
            thumbnails
                .where { $0.content._id == sttId.id }
                .count >= 1
        }

        var SaveForLaterButton: some View {
            Button {
                DataManager.shared.toggleReadLater(sttId.sourceId, sttId.contentId)
            } label: {
                Label(isSavedForLater ? "Remove from Read Later" : "Save For Later",
                      systemImage: isSavedForLater ? "circle.slash" : "clock")
            }
        }

        @ViewBuilder
        var MigrateButton: some View {
            if model.inLibrary {
                Button { model.presentMigrationView.toggle() } label: {
                    Label("Migrate", systemImage: "tray.full")
                }
            }
        }

        @ViewBuilder
        var ManageLinkedContentButton: some View {
            Button {
                model.presentManageContentLinks.toggle()
            } label: {
                Label("Linked Titles", systemImage: "link")
            }
        }

        @ViewBuilder
        var CustomThumbnailButton: some View {
            Button {
                if hasCustomThumb {
                    DataManager.shared.removeCustomThumbnail(id: sttId.id)
                } else {
                    presentImageSheet.toggle()
                }
            } label: {
                Label(hasCustomThumb ? "Remove Custom Thumb" : "Set Custom Thumbnail", systemImage: "photo")
            }
        }
    }
}
