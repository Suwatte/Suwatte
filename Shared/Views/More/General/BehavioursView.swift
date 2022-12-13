//
//  BehavioursView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-12-13.
//

import SwiftUI

struct BehavioursView: View {
    @AppStorage(STTKeys.HideNSFWRunners) var hideNSFWRunners = false
    @AppStorage(STTKeys.UpdateInterval) var updateInterval : STTUpdateInterval = .oneHour
    @AppStorage(STTKeys.CheckLinkedOnUpdateCheck) var checkLinkedOnUpdate = false
    @Preference(\.selectiveUpdates) var selectiveUpdates
    @AppStorage(STTKeys.IntialTabIndex) var InitialSelection = 3
    @AppStorage(STTKeys.OpenAllTitlesOnAppear) var openAllOnAppear = false
    
    @State private var presentAlert = false
    let options = AppTabs.defaultSettings
    var body: some View {
        List {
            // Initial Tab
            Section {
                NavigationLink {
                    List {
                        ForEach(Array(zip(options.indices, options)), id: \.0) { index, option in
                            SelectionLabel(label: option.label(), isSelected: index == InitialSelection, action: { InitialSelection = index })
                        }
                    }
                    .buttonStyle(.plain)
                    .navigationTitle("Opening Tab")
                } label: {
                    STTLabelView(title: "Opening Tab", label: options[InitialSelection].label())
                }
                
            } header: {
                Text("Tab")
            }
            .buttonStyle(.plain)
            
            // Open All Titles On Libary Appear
            Section {
                Toggle("Open Default Collection", isOn: $openAllOnAppear)
                LibraryAuthenticationToggleView()
            } header: {
                Text("Library")
            }
            
            Section {
                Picker("Minimum Update Interval", selection: $updateInterval) {
                    ForEach(STTUpdateInterval.allCases, id: \.rawValue) {
                        Text($0.label)
                            .tag($0)
                    }
                }
                Toggle("Check Linked Titles", isOn: $checkLinkedOnUpdate)
                Toggle(isOn: $selectiveUpdates) {
                    Text("Selective Updates \(Image(systemName: "info.circle"))")
                        .onTapGesture {
                            presentAlert.toggle()
                        }
                }
            } header: {
                Text("LIbrary Updates")
            }
            Section {
                Toggle("Hide NSFW Sources", isOn: $hideNSFWRunners)
            } header: {
                Text("Runners")
            }
        }
        .navigationBarTitle("Behaviours")
        .alert("Selective Updates", isPresented: $presentAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Suwatte will only fetch updates for titles flagged as 'Reading'.")
        }
        
    }
}

