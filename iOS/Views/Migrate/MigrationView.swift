//
//  MigrationView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-22.
//

import RealmSwift
import SwiftUI

struct MigrationView: View {
    @StateObject var model: MigrationController
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        ZStack {
            if model.hasLoadedSources && model.hasSortedContent {
                List {
                    Section {
                        STTLabelView(title: "Title Count", label: model.contents.count.description)
                        STTLabelView(title: "State", label: model.operationState.description)
                    }
                    switch model.operationState {
                    case .idle: SettingsSection
                    case .searching:
                        HStack {
                            Spacer()
                            VStack(alignment: .center) {
                                Text("Searching")
                                    .font(.headline)
                                    .fontWeight(.light)
                                ProgressView()
                            }
                            Spacer()
                        }
                    case .searchComplete: MigrationStrategySelectorView()
                    case .migrationComplete: Text("Done!").foregroundColor(.green)
                    }

                    MigrationEntryListView()
                }
                // Ugly hack, there is no SectionSeperatorSpacing in ios 15 so we need it right now
                .environment(\.defaultMinListHeaderHeight, 0)

            } else {
                ProgressView()
                    .task {
                        await model.loadSources()
                        await model.sortContents()
                    }
            }
        }
        .toast()
        .navigationTitle("Migrate")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: model.cancelOperations)
        .animation(.default, value: model.operationState)
        .alert("Start Migration", isPresented: $model.presentConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Start", role: .destructive) {
                Task {
                    let actor = try! await InnerMigrationActor(operations: model.operations, libStrat: model.libraryStrat, lessChStrat: model.lessChapterSrat)
                    let result = await actor.migrate()
                    guard result else { return }
                    await MainActor.run {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to begin the migration?\nA backup will be automatically generated to protect your data.")
        }
        .sheet(item: $model.selectedToSearch, content: { highlight in
            SmartNavigationView {
                MigrationManualDestinationView(content: highlight,
                                               searchModel: .init(preSources: model.preferredDestinations))
                    .closeButton()
            }
        })
        .environmentObject(model)
    }
}

extension MigrationView {
    var CAN_START: Bool {
        !model.preferredDestinations.isEmpty
    }
}

// MARK: Settings Section

extension MigrationView {
    var SettingsSection: some View {
        Section {
            NavigationLink {
                MigrationDestinationsLoadingView()
                    .environmentObject(model)
            } label: {
                STTLabelView(title: "Preferred Destinations", label: DestinationsLabel())
            }

            Button {
                Task.detached(priority: .userInitiated) {
                    await model.search()
                }
            } label: {
                Label("Begin Searches", systemImage: "magnifyingglass")
            }
            .disabled(!CAN_START)
        } header: {
            Text("Setup")
        }
        .buttonStyle(.plain)
    }

    func DestinationsLabel() -> String {
        var label = "No Selections"
        let count = model.preferredDestinations.count
        if count == 1 {
            label = model.preferredDestinations.first?.name ?? ""
        } else if count != 0 {
            label = "\(count) Sources"
        }
        return label
    }
}
