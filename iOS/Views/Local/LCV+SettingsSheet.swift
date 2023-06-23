//
//  LCV+SettingsSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-04.
//

import SwiftUI

extension LocalContentView {
    struct SetttingsSheet: View {
        @AppStorage(STTKeys.LocalThumnailOnly) var showOnlyThumbs = false
        @AppStorage(STTKeys.LocalHideInfo) var showTitleOnly = false
        var body: some View {
            List {
                Section {
                    Toggle("Show Only Thumbnails", isOn: $showOnlyThumbs)
                    Toggle("Hide Content Insight", isOn: $showTitleOnly)
                }
            }
        }
    }
}
