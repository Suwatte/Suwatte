//
//  ProfileView+Loadable.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Nuke
import RealmSwift
import SwiftUI

extension ProfileView {
    struct StateGate: View {
        @StateObject var viewModel: ProfileView.ViewModel
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            LoadableView(loadable: $viewModel.contentState) {
                await viewModel.setupObservers()
                await viewModel.load()
            } _: {
                PLACEHOLDER
            } _: {
                PLACEHOLDER
            } _: { error in
                ErrorView(error: error, runnerID: viewModel.source.id) {
                    await viewModel.load()
                }
            } _: { _ in
                ProfileView.Skeleton()
                    .navigationTitle(viewModel.content.title)
                    .transition(.opacity)
                    .fullScreenCover(item: $viewModel.selection) { chapter in
                        let readingMode = viewModel.readingMode
                        ReaderGateWay(title: viewModel.content.title,
                                      readingMode: readingMode,
                                      chapterList: viewModel.chapterListChapters,
                                      openTo: chapter)
                            .task {
                                viewModel.removeNotifier()
                            }
                            .onDisappear {
                                Task {
                                    await handleReconnection()
                                    ImagePipeline.shared.configuration.imageCache?.removeAll()
                                }
                            }
                    }
            }

            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if viewModel.source.intents.chapterEventHandler {
                        SyncView()
                            .frame(width: 7, height: 7, alignment: .center)
                            .transition(.opacity)
                    }
                    if viewModel.isWorking {
                        Circle()
                            .frame(width: 7, height: 7, alignment: .center)
                            .foregroundColor(.orange)
                            .transition(.opacity)
                    }
                }
            }
            .transition(.opacity)
            .environmentObject(viewModel)
        }

        @ViewBuilder
        var PLACEHOLDER: some View {
            ProgressView()
        }

        func handleReconnection() async {
            await viewModel.setupObservers()
        }
    }

    struct SyncView: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @State var isRotated = false
        var body: some View {
            switch model.syncState {
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
