//
//  ContentTrackerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import SwiftUI

struct ContentTrackerInfoView: View {
    var tracker: AnyContentTracker

    var body: some View {
        List {
            HeaderSection
            InfoSection

            if tracker.intents.authenticatable, tracker.intents.authenticationMethod != .unknown {
                DSKAuthView(model: .init(runner: tracker))
            }

            if tracker.intents.requiresSetup || tracker.intents.preferenceMenuBuilder {
                Section {
                    if tracker.intents.requiresSetup {
                        NavigationLink("Setup") {
                            DSKLoadableForm(runner: tracker, context: .setup(closeOnSuccess: false))
                                .navigationTitle("Setup")
                        }
                    }

                    if tracker.intents.preferenceMenuBuilder {
                        NavigationLink("Preferences") {
                            DSKLoadableForm(runner: tracker, context: .preference)
                                .navigationTitle("Preferences")
                        }
                    }

                } header: {
                    Text("Settings")
                }
            }
        }
        .navigationTitle(tracker.name)
    }

    var HeaderSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text(tracker.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(tracker.version.description)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .foregroundColor(.primary.opacity(0.5))
                }
            }
        }
    }

    @ViewBuilder
    var InfoSection: some View {
        if let url = URL(string: tracker.info.website ?? "") {
            Section {
                Link(destination: url) {
                    HStack {
                        Text("Visit Website")
                        Spacer()
                        Image(systemName: "globe")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
