//
//  FCS+Options.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-01-05.
//

import SwiftUI

struct FCS_Options: View {
    @EnvironmentObject var model: ProfileView.ViewModel
    @State var providers: [DSKCommon.ChapterProvider] = []
    @State var blacklisted: Set<String> = []
    
    var body: some View {
        SmartNavigationView {
            List {
                ProvidersSection
            }
            .closeButton()
            .navigationBarTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: providers)
            .task {
                getProviders()
                getBlacklisted()
            }
        }
    }
    
    var ProvidersSection: some View {
        Section {
            ForEach(providers) { provider in
                Button {
                    toggleBlacklist(provider.id)
                } label: {
                    HStack {
                        Text(provider.name)
                        Spacer()
                        Image(systemName: "checkmark")
                            .resizable()
                            .opacity(blacklisted.contains(provider.id) ? 0 : 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }
        } header: {
            Text("Providers")
        }
        .headerProminence(.increased)
    }
    
    func getProviders() {
        providers = model.chapters.compactMap(\.providers).flatMap({ $0 })
    }
    
    func getBlacklisted() {
        let id = model.sourceID
        blacklisted = Set(STTHelpers.getBlacklistedProviders(for: id))
    }
    
    func toggleBlacklist(_ id: String) {
        if blacklisted.contains(id) {
            blacklisted.remove(id)
        } else {
            blacklisted.insert(id)
        }
        
        STTHelpers.setBlackListedProviders(for: model.sourceID, values: Array(blacklisted))
    }
}
