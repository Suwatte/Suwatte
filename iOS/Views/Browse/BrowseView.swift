//
//  BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-27.
//

import RealmSwift
import SwiftUI

struct BrowseView: View {
    @ObservedResults(StoredRunnerObject.self, where: { $0.isDeleted == false }) var runners
    @State var presentImporter = false
    var body: some View {
        NavigationView {
            List {
                SearchSection
                if !sources.isEmpty {
                    InstalledSourcesSection
                }
                
                TrackersSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Browse")
        }
        .navigationViewStyle(.stack)
    }

    var SearchSection: some View {
        Section {
            NavigationLink("Search All Sources") {
                Text("Placeholder")
            }
            NavigationLink("Image Search") {
                ImageSearchView()
            }
        } header: {
            Text("Search")
        }
    }

    var FilteredRunners: Results<StoredRunnerObject> {
        runners
            .sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true),
                         SortDescriptor(keyPath: "name", ascending: true)])
    }
}

// MARK: Cotnent Source
extension BrowseView {
    var sources: Results<StoredRunnerObject> {
        FilteredRunners
            .where { $0.environment == .source }
    }

    @ViewBuilder
    var InstalledSourcesSection: some View {
        Section {
            ForEach(sources) { runner in
                NavigationLink {
                    SourceLandingPage(sourceID: runner.id)
                } label: {
                    HStack(spacing: 15) {
                        STTThumbView(url: URL(string: runner.thumbnail))
                            .frame(width: 32.0, height: 32.0)
                            .cornerRadius(5)
                        Text(runner.name)
                        Spacer()
                    }
                }
                .disabled(!runner.enabled)
            }
        } header: {
            Text("Content Sources")
        }
    }
}

// MARK: Trackers with Pages
extension BrowseView {
    var trackers: [StoredRunnerObject] {
        FilteredRunners
            .where { $0.environment == .tracker }
            .toArray()
    }
    
    @ViewBuilder
    var TrackersSection: some View {
        let plain = trackers.filter { !UserDefaults.standard.bool(forKey: STTKeys.PageLinkProvider($0.id)) }
        let advanced = trackers.filter { UserDefaults.standard.bool(forKey: STTKeys.PageLinkProvider($0.id)) }

        if !plain.isEmpty {
            Section {
                ForEach(plain) { runner in
                    NavigationLink {
                        TrackerLandingPage(trackerID: runner.id)
                    } label: {
                        HStack(spacing: 15) {
                            STTThumbView(url: URL(string: runner.thumbnail))
                                .frame(width: 32.0, height: 32.0)
                                .cornerRadius(5)
                            Text(runner.name)
                            Spacer()
                        }
                    }
                    .disabled(!runner.enabled)
                }
            }
        }
        if !advanced.isEmpty {
            ForEach(advanced) { runner in
                Section {
                    PageLinkProviderView(runnerID: runner.id)
                } header: {
                    Text(runner.name)
                }
            }
        }
    }
}


struct PageLinkProviderView: View {
    var runnerID: String
    @State private var loadable: Loadable<[DSKCommon.PageLink]> = .idle
    @State private var runner: Loadable<JSCRunner> = .idle
    
    var body: some View {
        LoadableView(startRunner, runner) { initializedRunner in
            LoadableView({ loadLinks(initializedRunner) }, loadable) { value in
                LinksView(value, initializedRunner)
            }
        }
    }
    
    func startRunner() {
        runner = .loading
        Task {
            do {
                let data = try DSK.shared.getJSCRunner(runnerID)
                withAnimation {
                    runner = .loaded(data)
                }
            } catch {
                Logger.shared.error(error)
                withAnimation {
                    runner = .failed(error)
                }
            }
        }
    }
    func loadLinks(_ runner: JSCRunner) {
        loadable = .loading

        Task {
            do {
                let data = try await runner.getBrowsePageLinks()
                withAnimation {
                    loadable = .loaded(data)
                }
            } catch {
                Logger.shared.error(error)
                withAnimation {
                    loadable = .failed(error)
                }
            }
        }
    }
    
    @ViewBuilder
    func LinksView(_ links: [DSKCommon.PageLink], _ runner: JSCRunner) -> some View {
        ForEach(links, id: \.hashValue) { pageLink in
            NavigationLink {
                Group {
                    if pageLink.link.isPageLink {
                        RunnerPageView(runner: runner, pageKey: pageLink.link.getPageKey())
                            .navigationBarTitle(pageLink.label)
                    } else {
                        RunnerDirectoryView(runner: runner, request: pageLink.link.getDirectoryRequest())
                            .navigationBarTitle(pageLink.label)
                    }
                }
            } label: {
                HStack {
                    STTThumbView(url: URL(string: pageLink.cover ?? "") ?? runner.thumbnailURL)
                        .frame(width: 32.0, height: 32.0)
                        .cornerRadius(5)
                    Text(pageLink.label)
                    Spacer()
                }
            }
        }
    }
}
