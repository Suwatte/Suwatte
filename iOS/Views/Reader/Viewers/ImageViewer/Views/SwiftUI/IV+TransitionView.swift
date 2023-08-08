//
//  IV+TransitionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-07.
//


import RealmSwift
import SwiftUI

struct ReaderTransitionView: View {
    let transition: ReaderTransition
    var body: some View {
        Group {
            switch transition.type {
            case .NEXT: NEXT
            case .PREV: PREV
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    var PREV: some View {
        if let destination = transition.to {
            BaseTransitionView(destination: destination, from: transition.from, type: transition.type)
        } else {
            FirstChapter
        }
    }

    @ViewBuilder
    var NEXT: some View {
        if let destination = transition.to {
            BaseTransitionView(destination: destination, from: transition.from, type: transition.type)
        } else {
            LastChapter
        }
    }

    @ViewBuilder
    var FirstChapter: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("(´• ω •`) ♡")
                .font(.title3)
                .fontWeight(.bold)
            Text("No Previous Chapters")
                .font(.headline)
                .fontWeight(.light)
        }
    }

    @ViewBuilder
    var LastChapter: some View {
        VStack(spacing: 100) {
            Text(CONTENT_COMPLETED ? "Completed" : "You're all caught up!")
                .font(.title3)
                .fontWeight(.light)

            ActionButtonsView()
        }
    }

    var CONTENT_COMPLETED: Bool {
//        viewModel.content?.status == .COMPLETED
        false
    }

    struct ActionButtonsView: View {
        @State var inLibrary = false
        @State var openCollectionSheet = false
        @State var wasInLibrary = false
        var body: some View {
            EmptyView()
//            if let content = model.content {
//                MAIN(entry: content)
//                    .task {
//                        inLibrary = model.isInLibrary
//                        wasInLibrary = inLibrary
//                    }
//            }
        }

        @ViewBuilder
        func MAIN(entry: StoredContent) -> some View {
            HStack(spacing: 15) {
                if !wasInLibrary {
                    ActionButton(label: inLibrary ? "Unfollow" : "Follow", systemImage: inLibrary ? "folder.fill" : "folder.badge.plus") {
                        let cID = entry.ContentIdentifier
                        Task {
                            let actor = await RealmActor()
                            let result = await actor.toggleLibraryState(for: cID)
                            Task { @MainActor in
                                inLibrary = result
                                if inLibrary { openCollectionSheet.toggle() }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .sheet(isPresented: $openCollectionSheet) {
                ProfileView.Sheets.LibrarySheet(id: entry.id)
            }
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(5)
            .opacity(wasInLibrary ? 0 : 1)
        }
    }

    struct ActionButton: View {
        var label: String
        var systemImage: String
        var action: () -> Void

        init(label: String, systemImage: String, _ action: @escaping () -> Void) {
            self.label = label
            self.systemImage = systemImage
            self.action = action
        }

        var body: some View {
            Button { action() } label: {
                VStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20, alignment: .center)

                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical)
            }
            .buttonStyle(.plain)
            .highPriorityGesture(tap)
        }

        var tap: some Gesture {
            TapGesture()
                .onEnded { _ in
                    action()
                }
        }
    }

    struct RecommendationsView: View {
        var body: some View {
            Text("Recommendations")
        }
    }

    struct BaseTransitionView: View {
        var destination: ThreadSafeChapter
        var from: ThreadSafeChapter
        var type: ReaderTransition.TransitionType
        var body: some View {
            VStack(spacing: 100) {
                // Header
                HeaderView

                // Reader Actions

                ActionButtonsView()
                // Check Jump
                if destination.volume == from.volume && destination.number - from.number > 1 {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Potentially Missing Chapters\nMoving from Chapter \(from.number.clean) to \(destination.number.clean)")
                            .font(.footnote)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.yellow)
                }

                // Up Next
                UpNextView
            }
        }

        var HeaderView: some View {
            VStack(alignment: .center) {
                Text("ଘ(੭*ˊᵕˋ)੭* ̀ˋ")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Chapter Completed")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(from.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            }
        }

        var UpNextView: some View {
            VStack {
                Text("UP NEXT")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fontWeight(.medium)
                Text(destination.displayName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary.opacity(0.75))
                if let title = destination.title {
                    Text(title)
                        .font(.caption2)
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.75))
                }
                
                ChapterStatusView
                    .frame(width: 15, height: 15, alignment: .center)
            }
        }

        var SYSTEM_IMAGE: String {
            if Preferences.standard.isReadingVertically {
                return "arrowtriangle.down.circle.fill"
            } else if Preferences.standard.readingLeftToRight {
                return "arrowtriangle.right.circle.fill"
            }
            return "arrowtriangle.left.circle.fill"
        }

        @ViewBuilder
        var ChapterStatusView: some View {
            Text("")
//            if let chapter = model.readerChapterList.first(where: { $0.chapter.id == destination.id }) {
//                // Loading Status
//                switch chapter.data {
//                case let .failed(error):
//                    ErrorView(error: error, action: {})
//                case .idle, .loading:
//                    ProgressView()
//                case .loaded:
//                    Image(systemName: SYSTEM_IMAGE)
//                        .resizable()
//                        .foregroundColor(.green)
//                }
//            }
        }
    }
}
