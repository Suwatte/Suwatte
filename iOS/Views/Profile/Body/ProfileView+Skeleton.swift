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
                        .environmentObject(StateManager.shared)
                })
                .fullScreenCover(item: $viewModel.presentManageContentLinks,
                                 onDismiss: {
                                     Task { [weak viewModel] in
                                         await viewModel?.updateContentLinks()
                                     }
                                 },
                                 content: { id in
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
    @ViewBuilder
    var Main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Header()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 5.5) {
                    Summary()
                    Divider()
                    if let properties = viewModel.content.properties, !properties.isEmpty {
                        CorePropertiesView()
                        Divider()
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 0) {
                    ChapterView.PreviewView()
                    AdditionalInfoView()
                    AdditionalCoversView()
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 20) {
                    if let collections = viewModel.content.collections, !collections.isEmpty {
                        RelatedContentView(collections: collections)
                    }
                }
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical)
            .padding(.bottom, 70)
        }
        .overlay(alignment: .bottom) {
            BottomBar()
                .background(Color.systemBackground)
        }
    }
}
