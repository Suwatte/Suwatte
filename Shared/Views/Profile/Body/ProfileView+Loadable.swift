//
//  CPV+Body.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import RealmSwift
import SwiftUI
import Nuke

extension ProfileView {
    struct StateGate: View {
        @StateObject var viewModel: ProfileView.ViewModel
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            LoadableView(loadable: viewModel.loadableContent,
                         { PLACEHOLDER
                             .task {
                                 Task.detached {
                                     await viewModel.loadContentFromDatabase()
                                 }
                                 viewModel.setupObservers()
                             }
                         },
                         { PLACEHOLDER },
                         { error in ErrorView(error: error, action: {
                             Task {
                                 await MainActor.run(body: {
                                     viewModel.loadableContent = .loading
                                 })
                                 await viewModel.loadContentFromNetwork()
                             }
                         }) },
                         { _ in
                             ProfileView.Skeleton()
                                 .navigationTitle(viewModel.content.title)
                                 .transition(.opacity)
                                 .fullScreenCover(item: $viewModel.selection, onDismiss: {
                                     print("dismissed")
                                     Task {
                                         handleReconnection()
                                         ImagePipeline.shared.configuration.imageCache?.removeAll()
                                     }
                                 }) { id in
                                     let chapterList = viewModel.chapters.value ?? []
                                     let chapter = chapterList.first(where: { $0.id == id })
                                     if let chapter = chapter {
                                         ReaderGateWay(readingMode: viewModel.content.recommendedReadingMode ?? .PAGED_COMIC, chapterList: chapterList, openTo: chapter)
                                             .onAppear {
                                                 viewModel.removeNotifier()
                                             }
                                     } else {
                                         NavigationView {
                                             Text("Invalid Chapter")
                                                 .closeButton()
                                         }
                                     }
                                 }
                         })

                         .toolbar {
                             ToolbarItemGroup(placement: .navigationBarTrailing) {
                                 if viewModel.source.config.canSyncWithSource {
                                     SyncView()
                                         .transition(.opacity)
                                 }
                                 if viewModel.working {
                                     Circle()
                                         .frame(width: 7, height: 7, alignment: .center)
                                         .foregroundColor(.orange)
                                         .transition(.opacity)
                                 }
                             }
                         }
                         .transition(.opacity)
                         .animation(.default)
                         .environmentObject(viewModel)
        }

        @ViewBuilder
        var PLACEHOLDER: some View {
            ProgressView()
        }

        func handleReconnection() {
            DispatchQueue.main.async {
                viewModel.setupObservers()
            }
        }
    }

    struct SyncView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @State var isRotated = false
        var body: some View {
            switch model.syncState {
            case .failure:
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15, alignment: .center)
                    .foregroundColor(.red)
                    .transition(.opacity)
                    .onTapGesture {
                        Task {
                            await model.handleSync()
                        }
                    }

            case .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 15, height: 15, alignment: .center)
                    .foregroundColor(.green)
                    .rotationEffect(Angle.degrees(isRotated ? 360 : 0))
                    .transition(.scale)
                    .animation(animation, value: isRotated)
                    .onAppear {
                        isRotated.toggle()
                    }
            default: EmptyView()
                .transition(.opacity)
            }
        }

        var animation: Animation {
            .linear
                .speed(0.25)
                .repeatForever(autoreverses: false)
        }
    }
}
