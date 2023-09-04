//
//  DirectoryViewer.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-20.
//

import NukeUI
import QuickLook
import QuickLookThumbnailing
import SwiftUI

struct DirectoryViewer: View {
    @StateObject var model: ViewModel
    @EnvironmentObject private var coreModel: CoreModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var isActive = false
    @State private var presentImportSheet = false
    @State private var presentSettingsSheet = false
    @State private var presentDownloadQueueSheet = false
    @State private var isEditing = false

    @Preference(\.directoryViewSortKey) private var directorySortKey
    @Preference(\.directoryViewOrderKey) private var directoryOrderKey

    var title: String?
    var body: some View {
        Group {
            if let directory = model.directory {
                if directory.files.isEmpty && directory.folders.isEmpty {
                    EmptyDirectoryView
                        .transition(.opacity)
                } else {
                    if model.query.isEmpty { // Not Searching
                        CoreCollectionView(directory: directory, isEditing: $isEditing)
                            .transition(.opacity)
                            .environmentObject(model)
                    } else if let results = model.searchResultsDirectory {
                        if results.files.isEmpty && results.folders.isEmpty {
                            NoResultsView // Searching but there are not files or folders matching query
                                .transition(.opacity)

                        } else {
                            CoreCollectionView(directory: results, isEditing: Binding.constant(false))
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
            guard isActive else { return }
            if newPhase == .active {
                model.observe()
            } else if newPhase == .background {
                model.stop()
            }
        }
        .onChange(of: coreModel.currentlyReading) { file in
            guard isActive else { return }
            if file != nil {
                model.stop()
            } else {
                model.observe()
            }
        }
        .onChange(of: directorySortKey, perform: { _ in
            guard isActive else { return }
            model.restart()
        })
        .onChange(of: directoryOrderKey, perform: { _ in
            guard isActive else { return }
            model.restart()
        })

        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ProgressView()
                    .opacity(model.working ? 1 : 0)

                Group {
                    if isEditing {
                        Button("Done") {
                            isEditing = false
                        }
                        .transition(.opacity)
                    } else {
                        Menu {
                            Button {
                                presentImportSheet.toggle()
                            } label: {
                                Label("Import Comics", systemImage: "plus")
                            }
                            Button {
                                model.createDirectory()
                            } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }

                            Button {
                                isEditing = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                            Divider()
                            Picker("Sort Library", selection: $directorySortKey) {
                                ForEach(DirectorySortOption.allCases, id: \.hashValue) { option in
                                    HStack {
                                        Text(option.description)
                                        Spacer()
                                    }
                                    .tag(option)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Order Library", selection: $directoryOrderKey) {
                                Text("Ascending")
                                    .tag(false)
                                Text("Descending")
                                    .tag(true)
                            }
                            .pickerStyle(.menu)
                            Divider()
                            Button {
                                presentDownloadQueueSheet.toggle()
                            } label: {
                                Label("Download Queue", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                presentSettingsSheet.toggle()
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Library")
        .modifier(OpenLocalModifier(isPresenting: $presentImportSheet))
        .sheet(isPresented: $presentSettingsSheet) {
            SettingsSheet()
        }
        .sheet(isPresented: $presentDownloadQueueSheet) {
            NavigationView {
                DownloadQueueSheet()
                    .closeButton()
            }
            
        }
        .animation(.default, value: isEditing)
    }

    var EmptyDirectoryView: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("(━┳━｡ Д ｡━┳━)")
                .font(.title)
            Text("it's empty here")
                .font(.footnote)
        }
        .foregroundColor(.gray)
    }

    var NoResultsView: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("(━┳━｡ Д ｡━┳━)")
                .font(.title)
            Text("No results found")
                .font(.footnote)
        }
        .foregroundColor(.gray)
    }
}
