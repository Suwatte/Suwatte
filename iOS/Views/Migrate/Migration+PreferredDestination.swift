//
//  Migration+PreferredDestination.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-27.
//

import SwiftUI

struct MigrationDestinationsLoadingView: View {
    @EnvironmentObject private var model: MigrationController

    var body: some View {
        Group {
            if model.hasLoadedSources {
                PreferredMigrationDestinationsView()
            } else {
                ProgressView()
                    .task {
                        await model.loadSources()
                    }
            }
        }
        .animation(.default, value: model.hasLoadedSources)
    }
}
struct PreferredMigrationDestinationsView: View {
    @EnvironmentObject private var model: MigrationController
    
    var body: some View {
        List {
            Section {
                ForEach(preferred, id: \.id) { source in
                    HStack {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                        Text(source.name)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        remove(source: source)
                    }
                }
                .onMove(perform: move)
            } header: {
                Text("Destinations")
            }

            Section {
                ForEach(available, id: \.id) { source in
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text(source.name)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        add(source: source)
                    }
                }
            } header: {
                Text("Available")
            }
        }
        .navigationTitle("Preferred Destinations")
        .environment(\.editMode, .constant(.active))
        .animation(.default, value: preferred.map(\.id))
        .animation(.default, value: available.map(\.id))
    }
    private var preferred: [AnyContentSource] {
        model.preferredDestinations
    }
    
    private var available: [AnyContentSource] {
        model.availableDestinations
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        model
            .preferredDestinations
            .move(fromOffsets: source, toOffset: destination)
    }
    
    private func remove(source: AnyContentSource) {
        model
            .availableDestinations
            .append(source)

        model
            .preferredDestinations
            .removeAll(where: { $0.id == source.id })

    }
    
    private func add(source: AnyContentSource) {
        model
            .preferredDestinations
            .append(source)
        model
            .availableDestinations
            .removeAll(where: { $0.id == source.id })
        
    }
}
