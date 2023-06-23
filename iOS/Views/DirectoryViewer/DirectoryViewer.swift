//
//  DirectoryViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import SwiftUI

import QuickLook
import QuickLookThumbnailing
import NukeUI

struct DirectoryViewer: View {
    @StateObject var model: ViewModel
    @EnvironmentObject var coreModel: CoreModel
    @Environment(\.scenePhase) var scenePhase
    @State private var isActive = false
    var title: String?
    var body: some View {
        Group {
            if let directory = model.directory {
                if directory.files.isEmpty && directory.folders.isEmpty {
                    EmptyDirectoryView
                        .transition(.opacity)
                } else {
                    
                    if model.query.isEmpty { // Not Searching
                        CoreCollectionView(directory: directory)
                            .transition(.opacity)
                            .environmentObject(model)
                    } else if let results = model.searchResultsDirectory {
                        if results.files.isEmpty && results.folders.isEmpty {
                            NoResultsView // Searching but there are not files or folders matching query
                                .transition(.opacity)

                        } else {
                            CoreCollectionView(directory: results)
                                .transition(.opacity)
                                .environmentObject(model)
                        }
                    } else {
                        ProgressView() // Searching but results have not been populated
                            .transition(.opacity)

                    }
                }
            } else {
                ProgressView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.directory)
        .animation(.easeInOut(duration: 0.35), value: model.searchResultsDirectory)
        .animation(.easeInOut(duration: 0.35), value: model.query)
        .task {
            isActive = true
            model.observe()
        }
        .onDisappear {
            isActive = false
            model.stop()
        }
        .navigationTitle(title ?? "Library")
        .onChange(of: scenePhase) { newPhase in
            guard isActive else { return}
            if newPhase == .active {
                model.observe()
            } else if newPhase == .background {
                model.stop()
            }
        }
        .onChange(of: coreModel.displayReader) { display in
            guard isActive else { return }
            if display {
                model.stop()
            } else {
                model.observe()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                ProgressView()
                    .opacity(model.working ? 1 : 0)
                
                Menu {
                    Text("Import")
                    Text("New Folder")
                    Text("Select")
                    Divider()
                    Text("Sort")
                    Text("Order")
                    Divider()
                    Text("Queue")
                    Text("Settings")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }

            }
        }
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Library")
        
    }
    
    var EmptyDirectoryView: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("(━┳━｡ Д ｡━┳━)")
                .font(.title)
            Text("No results found")
                .font(.footnote)
        }
        .foregroundColor(.gray)
    }
    
    var NoResultsView: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("(━┳━｡ Д ｡━┳━)")
                .font(.title)
            Text("it's empty here")
                .font(.footnote)
        }
        .foregroundColor(.gray)
    }
}

