//
//  ProfileView+Skeleton.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import RealmSwift
import SwiftUI
extension ProfileView {
    struct Skeleton: View {
        @EnvironmentObject var viewModel: ProfileView.ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
        var body: some View {
            Main
                .fullScreenCover(isPresented: $viewModel.presentCollectionsSheet, content: {
                    ProfileView.Sheets.LibrarySheet(id: viewModel.identifier)
                        .tint(accentColor)
                        .accentColor(accentColor)
                })
                .fullScreenCover(isPresented: $viewModel.presentTrackersSheet, content: {
                    let titles = (viewModel.content.additionalTitles ?? []).appending(viewModel.content.title).distinct()
                    TrackerManagementView(model: .init(id: viewModel.identifier, titles))
                        .tint(accentColor)
                        .accentColor(accentColor)
                })
                .fullScreenCover(item: $viewModel.presentManageContentLinks, content: { id in
                    SmartNavigationView {
                        ManageContentLinks(id: id,
                                           highlight: .init(id: viewModel.contentID,
                                                            cover: viewModel.content.cover,
                                                            title: viewModel.content.title))
                            .closeButton()
                    }
                    .tint(accentColor)
                    .accentColor(accentColor)
                })
                .fullScreenCover(isPresented: $viewModel.presentMigrationView, content: {
                    let tagged = TaggedHighlight(from: viewModel.entry, with: viewModel.sourceID)
                    SmartNavigationView {
                        MigrationView(model: .init(contents: [tagged]))
                            .closeButton()
                    }
                })
                .transition(.opacity)
        }
    }
}

private extension ProfileView.Skeleton {
    var Main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Header()

                VStack(spacing: 5.5) {
                    Summary()
                    Divider()
                    CorePropertiesView()
                    Divider()
                }
                .padding(.horizontal)

                ChapterView.PreviewView()
                    .padding(.horizontal)

                AdditionalInfoView()
                AdditionalCoversView()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 20) {
                    if let collections = viewModel.content.collections, !collections.isEmpty {
                        RelatedContentView(collections: collections)
                    }
                }
                .padding(.top, 5)
            }
            .padding(.vertical)
            .padding(.bottom, 70)
        }
        .overlay(alignment: .bottom) {
            BottomBar()
                .background(Color.systemBackground)
        }
    }
}
