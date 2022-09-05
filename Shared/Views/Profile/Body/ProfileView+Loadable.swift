//
//  CPV+Body.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import Kingfisher
import RealmSwift
import SwiftUI
extension ProfileView {
    struct StateGate: View {
        @StateObject var viewModel: ProfileView.ViewModel
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            LoadableView(loadable: viewModel.content,
                         { PLACEHOLDER
                             .onAppear {
                                 viewModel.loadContentFromDatabase()
                             }
                         },
                         { PLACEHOLDER },
                         { error in ErrorView(error: error, action: {
                             Task {
                                 await MainActor.run(body: {
                                     viewModel.content = .loading
                                 })
                                 await viewModel.loadContentFromNetwork()
                             }
                         }) },
                         { entry in
                             ProfileView.Skeleton()
                                 .navigationTitle(entry.title)
                                 .fullScreenCover(item: $viewModel.selection, onDismiss: {
                                     Task {
                                         viewModel.getMarkers()
                                         KingfisherManager.shared.cache.clearMemoryCache()
                                     }
                                 }) { id in
                                     let chapterList = viewModel.chapters.value ?? []
                                     let chapter = chapterList.first(where: { $0._id == id })
                                     if let chapter = chapter {
                                         ReaderGateWay(readingMode: entry.recommendedReadingMode, chapterList: chapterList, openTo: chapter)
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
                                 .environmentObject(entry)
                         })

                         .toolbar {
                             ToolbarItemGroup(placement: .navigationBarTrailing) {
                                 if viewModel.source.sourceInfo.canSync {
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

                         .animation(.default)
                         .environmentObject(viewModel)
                         .environmentObject(viewModel.source)
        }

        @ViewBuilder
        var PLACEHOLDER: some View {
            ProgressView()
            //            Group {
            //                if let placeholder = ContentPlaceholder() {
            //                    ProfileView.Skeleton(entry: placeholder)
            //                        .redacted(reason: .placeholder)
            //                        .shimmering()
            //                } else {
            //                    ProgressView()
            //                }
            //
            //            }
        }

        func ContentPlaceholder() -> StoredContent? {
            if let url = Bundle.main.url(forResource: "placeholder", withExtension: "json") {
                do {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let jsonData = try decoder.decode(StoredContent.self, from: data)
                    let realm = try! Realm()

                    try! realm.safeWrite {
                        realm.add(jsonData, update: .all)
                    }

                    return jsonData
                } catch {
                    print("error:\(error)")
                }
            }
            return nil
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
