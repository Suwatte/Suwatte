//
//  LibraryGrid+OptionsSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import SwiftUI
enum LibraryBadge: Int, CaseIterable {
    case unread, update

    var description: String {
        switch self {
        case .unread: return "Unread Count"
        case .update: return "Update Count"
        }
    }
}

extension LibraryView.LibraryGrid {
    struct OptionsSheet: View {
        @AppStorage(STTKeys.LibraryShowBadges) var showBadges = true
        @AppStorage(STTKeys.LibraryBadgeType) var badgeType: LibraryBadge = .update
        @AppStorage(STTKeys.ShowOnlyDownloadedTitles) var showDownloadsOnly = false
        var collection: LibraryCollection?
        var body: some View {
            SmartNavigationView {
                List {
                    Section {
                        Toggle("Show Badges", isOn: $showBadges)
                        if showBadges {
                            Picker("Badge Type", selection: $badgeType) {
                                ForEach(LibraryBadge.allCases, id: \.rawValue) {
                                    Text($0.description)
                                        .tag($0)
                                }
                            }
                        }
                        Toggle("Show Only Downloaded Titles", isOn: $showDownloadsOnly)
                    }

                    Section {
                        if let collection = collection?.thaw() {
                            NavigationLink("Collection Settings") {
                                CollectionManagementView(collection: collection, collectionName: collection.name)
                            }
                        }
                    }
                }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .animation(.default, value: showBadges)
                .closeButton()
            }
        }
    }
}
