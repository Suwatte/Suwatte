//
//  DRV+Actions.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-09-26.
//

import SwiftUI


extension DaisukeContentSourceView {
    
    
    struct ActionsView: View {
        @EnvironmentObject var source: DSK.ContentSource
        @State var loadable: Loadable<[DSKCommon.ActionGroup]?> = .idle
        var body: some View {
            LoadableView(loadable: loadable) {
                ProgressView()
                    .task {
                        await load()
                    }
            } _: {
                ProgressView()
            } _: { error in
                ErrorView(error: error, action: {
                    Task {
                        await load()
                    }
                }, sourceID: source.id)
            } _: { value in
                if let value {
                    Loaded(data: value)
                } else {
                    Text("This source has no actions :)")
                        .font(.headline.weight(.light))
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Actions")
            
        }
        
        @MainActor
        func load() async {
            loadable = .loading
            do {
                let data = try await source.getSourceActions()
                loadable = .loaded(data)
            } catch {
                loadable = .failed(error)
            }
        }
        
        @ViewBuilder
        func Loaded( data: [DSKCommon.ActionGroup]) -> some View {
            List {
                ForEach(data) { group in
                    Cell(group)
                }
            }
        }
        
        @ViewBuilder
        func Cell(_ data: DSKCommon.ActionGroup) -> some View {
            Section {
                ForEach(data.children) { action in
                    Button { trigger(action.key) } label: {
                        HStack {
                            VStack {
                                Text(action.title)
                                if let subtitle = action.subtitle {
                                    Text(subtitle)
                                        .font(.caption)
                                        .fontWeight(.light)
                                }
                            }
                            Spacer()
                            if let image = action.systemImage {
                                Image(systemName: image)
                            }
                            
                        }
                    }
                    .buttonStyle(.plain)
                    .conditional(action.destructive) { view in
                        view
                            .foregroundColor(.red)
                    }
                    
                    
                }
            } header: {
                if let header = data.header {
                    Text(header)
                }
            } footer: {
                if let footer = data.footer {
                    Text(footer)
                }
            }
            
        }
        
        func trigger(_ key: String) {
            Task { @MainActor in
                ToastManager.shared.loading.toggle()
                defer { ToastManager.shared.loading.toggle() }
                do {
                    try await source.didTriggerAction(key: key)
                } catch {
                    ToastManager.shared.error(error)
                }
                
            }
        }
    }
    
    
}
