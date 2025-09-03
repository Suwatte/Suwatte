//
//  LibraryGrid+OptionsSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-25.
//

import RealmSwift
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
        @AppStorage(STTKeys.LibraryPinningType) var pinningType: TitlePinningType = .unread
        @AppStorage(STTKeys.LibraryEnableTitlePinning) var enableTitlePinning = false
        @EnvironmentObject var model: LibraryView.LibraryGrid.ViewModel

        var body: some View {
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

                    Toggle("Pin Titles", isOn: $enableTitlePinning)
                    if enableTitlePinning {
                        HStack {
                            Text("Pin Type")
                            Spacer()
                            Picker("", selection: $pinningType) {
                                ForEach(TitlePinningType.pinTypes, id: \.self) {
                                    Text($0.description)
                                }
                            }
                            .pickerStyle(.segmented)
                            .fixedSize()
                        }
                    }
                } header: {
                    Text("Global Settings")
                }

                if let collection = model.collection?.thaw() {
                    Section {} header: {
                        Text("Collection Settings")
                    }

                    CollectionManagementView(collection: collection, collectionName: collection.name)
                }
            }
            .navigationTitle("Collection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: showBadges)
            .animation(.default, value: enableTitlePinning)
            .closeButton()
        }
    }
}
