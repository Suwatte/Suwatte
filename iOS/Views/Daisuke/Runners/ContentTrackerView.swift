//
//  ContentTrackerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-07.
//

import SwiftUI

struct ContentTrackerInfoView: View {
    var tracker: JSCContentTracker

    var body: some View {
        List {
            HeaderSection
            InfoSection

            if tracker.intents.authenticatable, tracker.intents.authenticationMethod != .unknown {
                DSKAuthView(model: .init(runner: tracker))
            }

            if tracker.intents.preferenceMenuBuilder {
                Section {
                    NavigationLink("Preferences") {
                        DSKPreferenceView(runner: tracker)
                            .navigationTitle("Preferences")
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

    var InfoSection: some View {
        Section {
            Link(destination: URL(string: tracker.trackerInfo.website) ?? STTHost.notFound) {
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
