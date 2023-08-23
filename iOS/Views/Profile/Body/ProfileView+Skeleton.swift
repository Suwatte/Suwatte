//
//  CPV+Body.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-07.
//

import BetterSafariView
import RealmSwift
import SwiftUI
extension ProfileView {
    struct Skeleton: View {
        @EnvironmentObject var viewModel: ProfileView.ViewModel
        @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault

        var body: some View {
            Main
                .fullScreenCover(isPresented: $viewModel.presentCollectionsSheet, content: {
                    ProfileView.Sheets.LibrarySheet(id: viewModel.contentIdentifier)
                        .tint(accentColor)
                        .accentColor(accentColor)
                })
                .fullScreenCover(isPresented: $viewModel.presentTrackersSheet, content: {
                    let titles = (viewModel.content.additionalTitles ?? []).appending(viewModel.content.title).distinct()
                    TrackerManagementView(model: .init(id: viewModel.contentIdentifier, titles))
                        .tint(accentColor)
                        .accentColor(accentColor)
                })
                .fullScreenCover(isPresented: $viewModel.presentManageContentLinks, content: {
                    NavigationView {
                        ManageContentLinks(content: viewModel.storedContent)
                            .closeButton()
                    }
                    .tint(accentColor)
                    .accentColor(accentColor)
                })
                .fullScreenCover(isPresented: $viewModel.presentMigrationView, content: {
                    NavigationView {
                        MigrationView(contents: [viewModel.storedContent])
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") {
                                        viewModel.presentMigrationView.toggle()
                                    }
                                }
                            }
                    }
                })
                .safariView(isPresented: $viewModel.presentSafariView) {
                    SafariView(
                        url: URL(string: viewModel.content.webUrl ?? "") ?? STTHost.notFound,
                        configuration: SafariView.Configuration(
                            entersReaderIfAvailable: false,
                            barCollapsingEnabled: true
                        )
                    )
                    .preferredControlAccentColor(accentColor)
                    .dismissButtonStyle(.close)
                }
                .transition(.opacity)
                .onDisappear {
                    self.viewModel.currentMarkerToken?.invalidate()
                }
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
                    if let collections = viewModel.content.includedCollections, !collections.isEmpty {
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
