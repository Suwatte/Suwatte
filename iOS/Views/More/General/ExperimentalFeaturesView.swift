//
//  ExperimentalFeaturesView.swift
//  Suwatte (iOS)
//
//  Created by Seyden on 2024-12-03.
//

import SwiftUI

struct ExperimentalFeaturesView: View {
    @AppStorage(STTKeys.UseWebKitDirective) var useWebKitDirective = false

    var body: some View {
        List {
            Section {
                Toggle("Use WebKit Engine", isOn: $useWebKitDirective)
            } header: {
                Text("Runners")
            }
        }
        .navigationTitle("Experimental Features")
    }
}
