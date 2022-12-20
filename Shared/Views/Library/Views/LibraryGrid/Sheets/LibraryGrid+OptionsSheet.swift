//
//  LibraryGrid+OptionsSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import SwiftUI

extension LibraryView.LibraryGrid {
    struct OptionsSheet: View {
        @AppStorage(STTKeys.ShowUpdateBadges) var showUpdateBadges = true
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) var showDownloadsOnly = false
        var collection: LibraryCollection?
        var body: some View {
            NavigationView {
                List {
                    Section {
                        Toggle("Show Update Badges", isOn: $showUpdateBadges)
                        Toggle("Show Only Downloaded Titles", isOn: $showDownloadsOnly)
                    }

                    Section {
                        if let collection = collection?.thaw() {
                            NavigationLink("Collection Settings") {
                                CollectionManagementView(collection: collection, collectionName: collection.name)
                            }
                        }

                        NavigationLink("View Statistics") {
                            Text("Stats Breakdown Per Source")
                        }
                    }
                }
                .navigationTitle("More")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
            }
        }
    }
}
